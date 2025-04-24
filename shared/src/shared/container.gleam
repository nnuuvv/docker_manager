import gleam/json
import gleam/dynamic/decode
import shared/container_data.{type ContainerData}

pub type Container {
  Container(data: ContainerData, selected: Bool)
}

pub fn encode_container(container: Container) -> json.Json {
  let Container(data:, selected:) = container
  json.object([
    #("data", container_data.encode_container_data(data)),
    #("selected", json.bool(selected)),
  ])
}

pub fn container_decoder() -> decode.Decoder(Container) {
  use data <- decode.field("data", container_data.container_data_decoder())
  use selected <- decode.field("selected", decode.bool)
  decode.success(Container(data:, selected:))
}
