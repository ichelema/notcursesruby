// ncvt: esegue un comando su un pty e fa da terminale con libghostty-vt 1.x.
//
// Uso: ncvt [-c COLONNE] [-r RIGHE] [-t SECONDI] [-m] [-s FILE] -- comando [argomenti...]
//   -c, -r  dimensioni del terminale (default 80x24)
//   -t      limite di tempo totale (default 30): poi SIGKILL al gruppo del comando
//   -m      terminale muto: non risponde a nessuna query (DA1, posizione del cursore, ...)
//   -s FILE punti di controllo: quando il comando crea FILE (la prima riga è un'etichetta),
//           ncvt aspetta che l'output si fermi, stampa lo stato, cancella FILE e crea
//           FILE.done; il comando aspetta FILE.done, lo cancella e prosegue
//
// Output: "=== pid N", uno "=== snapshot ETICHETTA" per ogni punto di controllo e uno
// finale, poi "=== exit ...". Uno snapshot ha la riga del cursore (posizione da 0,
// visibilità del modo 25, schermo attivo, risposte scritte al comando) e le righe dello
// schermo, numerate da 0. Exit status: 0 se il comando esce con 0, 124 al limite di
// tempo, 1 negli altri casi.
#define _GNU_SOURCE
#include <errno.h>
#include <getopt.h>
#include <poll.h>
#include <pty.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include <ghostty/vt.h>

static int master_fd = -1;
static bool mute = false;
static unsigned long replies = 0;

static long long now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

// Le risposte del terminale (DA1, posizione del cursore, modi, ...) tornano al comando.
static void on_write_pty(GhosttyTerminal terminal, void *userdata, const uint8_t *data, size_t len) {
  (void)terminal;
  (void)userdata;
  replies++;
  if (mute) return;
  while (len > 0) {
    ssize_t n = write(master_fd, data, len);
    if (n < 0) {
      if (errno == EINTR) continue;
      fprintf(stderr, "ncvt: write sul pty: %s\n", strerror(errno));
      return;
    }
    data += n;
    len -= (size_t)n;
  }
}

// Legge l'output del comando per al più wait_ms e lo passa al terminale.
// Restituisce i byte letti, 0 se non è arrivato niente, -1 a fine output (EOF o EIO).
static ssize_t feed(GhosttyTerminal terminal, int wait_ms) {
  struct pollfd p = {.fd = master_fd, .events = POLLIN};
  int rc = poll(&p, 1, wait_ms);
  if (rc < 0) return errno == EINTR ? 0 : -1;
  if (rc == 0) return 0;
  uint8_t buf[65536];
  ssize_t n = read(master_fd, buf, sizeof buf);
  if (n < 0) return errno == EINTR || errno == EAGAIN ? 0 : -1;
  if (n == 0) return -1;
  ghostty_terminal_vt_write(terminal, buf, (size_t)n);
  return n;
}

// Passa al terminale l'output finché per quiet_ms non arriva più niente.
static bool drain(GhosttyTerminal terminal, int quiet_ms) {
  ssize_t n;
  while ((n = feed(terminal, quiet_ms)) > 0) {
  }
  return n == 0;
}

static void snapshot(GhosttyTerminal terminal, const char *label) {
  uint16_t x = 0, y = 0;
  bool visible = false;
  GhosttyTerminalScreen screen = GHOSTTY_TERMINAL_SCREEN_PRIMARY;
  ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_CURSOR_X, &x);
  ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_CURSOR_Y, &y);
  ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_CURSOR_VISIBLE, &visible);
  ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_ACTIVE_SCREEN, &screen);
  printf("=== snapshot %s\n", label);
  printf("cursor x=%u y=%u visible=%d screen=%s replies=%lu\n", x, y, visible,
         screen == GHOSTTY_TERMINAL_SCREEN_ALTERNATE ? "alternate" : "primary", replies);

  GhosttyFormatter formatter;
  if (ghostty_formatter_terminal_new(NULL, &formatter, terminal) != GHOSTTY_SUCCESS) {
    printf("(formatter non disponibile)\n");
    return;
  }
  bool trim = false; // tiene tutte le righe: il numero di riga è la y del cursore
  ghostty_formatter_set(formatter, GHOSTTY_FORMATTER_OPT_TRIM, &trim);
  uint8_t *text = NULL;
  size_t len = 0;
  if (ghostty_formatter_format_alloc(formatter, NULL, &text, &len) == GHOSTTY_SUCCESS) {
    // il formatter scrive prima lo scrollback, poi lo schermo, senza le righe vuote in fondo:
    // le righe dello scrollback hanno un numero negativo e non si stampano
    size_t scrollback = 0;
    ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_SCROLLBACK_ROWS, &scrollback);
    long row = -(long)scrollback;
    int start = 0;
    for (size_t i = 0; i <= len; i++) {
      if (i == len || text[i] == '\n') {
        size_t end = i;
        while (end > (size_t)start && text[end - 1] == ' ') end--;
        if (row >= 0) printf("%3ld|%.*s\n", row, (int)(end - (size_t)start), (const char *)text + start);
        row++;
        start = (int)i + 1;
      }
    }
    ghostty_free(NULL, text, len);
  }
  ghostty_formatter_free(formatter);
}

// Un punto di controllo chiesto dal comando: etichetta da FILE, stato, poi FILE.done.
static void checkpoint(GhosttyTerminal terminal, const char *file) {
  char label[256] = "";
  FILE *f = fopen(file, "r");
  if (!f) return;
  if (!fgets(label, sizeof label, f)) label[0] = '\0';
  fclose(f);
  label[strcspn(label, "\r\n")] = '\0';
  unlink(file);
  drain(terminal, 200);
  snapshot(terminal, label[0] ? label : "punto di controllo");
  char done[4096];
  snprintf(done, sizeof done, "%s.done", file);
  f = fopen(done, "w");
  if (f) fclose(f);
}

static void usage(void) {
  fprintf(stderr, "uso: ncvt [-c COLONNE] [-r RIGHE] [-t SECONDI] [-m] [-s FILE] -- comando [argomenti...]\n");
  exit(2);
}

int main(int argc, char **argv) {
  int cols = 80, rows = 24, limit = 30, opt;
  const char *control = NULL;
  while ((opt = getopt(argc, argv, "+c:r:t:ms:")) != -1) {
    switch (opt) {
      case 'c': cols = atoi(optarg); break;
      case 'r': rows = atoi(optarg); break;
      case 't': limit = atoi(optarg); break;
      case 'm': mute = true; break;
      case 's': control = optarg; break;
      default: usage();
    }
  }
  if (optind >= argc || cols <= 0 || rows <= 0 || limit <= 0) usage();
  setvbuf(stdout, NULL, _IOLBF, 0);

  struct winsize ws = {.ws_row = (unsigned short)rows, .ws_col = (unsigned short)cols};
  pid_t pid = forkpty(&master_fd, NULL, NULL, &ws);
  if (pid < 0) {
    perror("ncvt: forkpty");
    return 1;
  }
  if (pid == 0) {
    execvp(argv[optind], &argv[optind]);
    fprintf(stderr, "ncvt: exec %s: %s\n", argv[optind], strerror(errno));
    _exit(127);
  }
  printf("=== pid %d\n", pid);

  GhosttyTerminal terminal;
  if (ghostty_terminal_new(NULL, &terminal, (uint16_t)cols, (uint16_t)rows) != GHOSTTY_SUCCESS) {
    fprintf(stderr, "ncvt: ghostty_terminal_new fallita\n");
    kill(-pid, SIGKILL);
    return 1;
  }
  ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_WRITE_PTY, (const void *)on_write_pty);

  long long deadline = now_ms() + (long long)limit * 1000;
  int status = 0;
  bool exited = false, timed_out = false;
  while (!exited) {
    if (now_ms() > deadline) {
      timed_out = true;
      kill(-pid, SIGKILL);
      break;
    }
    ssize_t n = feed(terminal, 50);
    if (control && access(control, F_OK) == 0) checkpoint(terminal, control);
    if (waitpid(pid, &status, WNOHANG) == pid) {
      exited = true;
      drain(terminal, 100);
    } else if (n < 0) {
      // il comando ha chiuso il pty ma non è ancora uscito: aspetta fino al limite
      while (!exited && now_ms() <= deadline) {
        if (waitpid(pid, &status, WNOHANG) == pid) exited = true;
        else usleep(20000);
      }
    }
  }
  snapshot(terminal, timed_out ? "limite di tempo" : "fine");
  if (!exited) waitpid(pid, &status, 0);
  if (timed_out) printf("=== exit timeout dopo %d s (SIGKILL)\n", limit);
  else if (WIFEXITED(status)) printf("=== exit status=%d\n", WEXITSTATUS(status));
  else if (WIFSIGNALED(status)) printf("=== exit signal=%d\n", WTERMSIG(status));
  ghostty_terminal_free(terminal);
  close(master_fd);
  if (timed_out) return 124;
  return WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : 1;
}
