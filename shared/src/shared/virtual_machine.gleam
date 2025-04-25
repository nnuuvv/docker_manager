import gleam/dynamic/decode
import gleam/json
import gleam/option
import shared/container
import shared/element_state

pub type VirtualMachine {
  VirtualMachine(
    name: String,
    containers: option.Option(List(container.Container)),
    element_state: element_state.ElementState,
  )
}

pub fn encode_virtual_machine(virtual_machine: VirtualMachine) -> json.Json {
  let VirtualMachine(name:, containers:, element_state:) = virtual_machine
  json.object([
    #("name", json.string(name)),
    #("containers", case containers {
      option.None -> json.null()
      option.Some(value) -> json.array(value, container.encode_container)
    }),
    #("element_state", element_state.encode_element_state(element_state)),
  ])
}

pub fn virtual_machine_decoder() -> decode.Decoder(VirtualMachine) {
  use name <- decode.field("name", decode.string)
  use containers <- decode.field(
    "containers",
    decode.optional(decode.list(container.container_decoder())),
  )
  use element_state <- decode.field(
    "element_state",
    element_state.element_state_decoder(),
  )
  decode.success(VirtualMachine(name:, containers:, element_state:))
}
