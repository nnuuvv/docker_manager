import gleam/dynamic/decode
import gleam/json
import gleam/option
import shared/container
import shared/virtual_machine.{type VirtualMachine}

pub type Node {
  Node(
    name: String,
    containers: option.Option(List(container.Container)),
    virtual_machines: option.Option(List(VirtualMachine)),
  )
}

pub fn encode_node(node: Node) -> json.Json {
  let Node(name:, containers:, virtual_machines:) = node
  json.object([
    #("name", json.string(name)),
    #("containers", case containers {
      option.None -> json.null()
      option.Some(value) -> json.array(value, container.encode_container)
    }),
    #("virtual_machines", case virtual_machines {
      option.None -> json.null()
      option.Some(value) ->
        json.array(value, virtual_machine.encode_virtual_machine)
    }),
  ])
}

pub fn node_decoder() -> decode.Decoder(Node) {
  use name <- decode.field("name", decode.string)
  use containers <- decode.field(
    "containers",
    decode.optional(decode.list(container.container_decoder())),
  )
  use virtual_machines <- decode.field(
    "virtual_machines",
    decode.optional(decode.list(virtual_machine.virtual_machine_decoder())),
  )
  decode.success(Node(name:, containers:, virtual_machines:))
}
