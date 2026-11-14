# frozen_string_literal: true

# Le action di terzi ricevono i secret del workflow: un tag come v7 si sposta
# a ogni release, uno SHA completo no (ICH-311).
RSpec.describe "Workflow della CI" do
  it "ogni action fuori da actions/ è fissata a uno SHA completo, con la versione in un commento" do
    workflow = File.read(File.expand_path("../.github/workflows/ci.yml", __dir__))
    uses = workflow.scan(/^\s*(?:-\s*)?uses:\s*(.+)$/).flatten.map(&:strip)
    third_party = uses.reject { |ref| ref.start_with?("actions/") }
    expect(third_party).not_to be_empty
    expect(third_party).to all(match(/\A[\w.-]+\/[\w.\/-]+@\h{40} # v\d+(\.\d+)*\z/))
  end
end
