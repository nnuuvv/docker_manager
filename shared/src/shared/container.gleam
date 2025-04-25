import gleam/dynamic/decode
import gleam/json
import shared/container_data.{type ContainerData}

pub type Container {
  Container(data: ContainerData)
}

pub fn encode_container(container: Container) -> json.Json {
  let Container(data:) = container
  json.object([#("data", container_data.encode_container_data(data))])
}

pub fn container_decoder() -> decode.Decoder(Container) {
  use data <- decode.field("data", container_data.container_data_decoder())
  decode.success(Container(data:))
}
