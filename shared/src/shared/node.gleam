import gleam/json
import gleam/dynamic/decode
import shared/virtual_machine.{type VirtualMachine}

pub type Node {
  Node(name: String, virtual_machines: List(VirtualMachine), selected: Bool)
}

pub fn encode_node(node: Node) -> json.Json {
  let Node(name:, virtual_machines:, selected:) = node
  json.object([
    #("name", json.string(name)),
    #("virtual_machines", json.array(virtual_machines, virtual_machine.encode_virtual_machine)),
    #("selected", json.bool(selected)),
  ])
}

pub fn node_decoder() -> decode.Decoder(Node) {
  use name <- decode.field("name", decode.string)
  use virtual_machines <- decode.field("virtual_machines", decode.list(virtual_machine.virtual_machine_decoder()))
  use selected <- decode.field("selected", decode.bool)
  decode.success(Node(name:, virtual_machines:, selected:))
}
