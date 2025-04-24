import gleam/dynamic/decode
import gleam/json
import gleam/option
import shared/container

pub type VirtualMachine {
  VirtualMachine(
    name: String,
    containers: option.Option(List(container.Container)),
    selected: Bool,
  )
}

pub fn encode_virtual_machine(virtual_machine: VirtualMachine) -> json.Json {
  let VirtualMachine(name:, containers:, selected:) = virtual_machine
  json.object([
    #("name", json.string(name)),
    #("containers", case containers {
      option.None -> json.null()
      option.Some(value) -> json.array(value, container.encode_container)
    }),
    #("selected", json.bool(selected)),
  ])
}

pub fn virtual_machine_decoder() -> decode.Decoder(VirtualMachine) {
  use name <- decode.field("name", decode.string)
  use containers <- decode.field(
    "containers",
    decode.optional(decode.list(container.container_decoder())),
  )
  use selected <- decode.field("selected", decode.bool)
  decode.success(VirtualMachine(name:, containers:, selected:))
}
