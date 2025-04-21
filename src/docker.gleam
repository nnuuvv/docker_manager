import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string
import lustre.{type App}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import shellout

pub fn component() -> App(_, Model, Msg) {
  lustre.simple(init, update, view)
}

// MODEL --------------------------------------------------------------------

pub type Model =
  List(ContainerData)

fn init(_) -> Model {
  let assert Ok(data) = get_running_containers()
  data
}

// UPDATE -------------------------------------------------------------------

pub opaque type Msg {
  FetchData
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    FetchData -> {
      let value = get_running_containers()

      case value {
        Error(_) -> model
        Ok(value) -> value
      }
    }
  }
}

// VIEW ---------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let styles = [#("display", "flex"), #("justify-content", "space-between")]
  html.div([attribute.styles(styles)], [
    html.button([event.on_click(FetchData)], [html.text("Update")]),
    html.div(
      [attribute.styles(styles)],
      list.map(model, fn(item) { view_container(item) }),
    ),
  ])
}

fn view_container(data: ContainerData) {
  html.div([], [
    html.text(
      "Container: " <> list.fold(data.names, "", fn(a, b) { a <> " " <> b }),
    ),
  ])
}

// GET DATA -----------------------------------------------------------------

fn get_running_containers() -> Result(List(ContainerData), json.DecodeError) {
  use shell_result <- result.try(
    shellout.command(
      run: "curl",
      with: [
        "--unix-socket", "/var/run/docker.sock", "http:///v1.49/containers/json",
      ],
      in: ".",
      opt: [],
    )
    |> result.replace_error(json.UnexpectedEndOfInput),
  )

  string.split_once(shell_result, "[")
  |> result.map(fn(splits) { string.append("[", pair.second(splits)) })
  |> result.replace_error(json.UnexpectedEndOfInput)
  |> result.try(fn(data_json) {
    json.parse(data_json, decode.list(container_data_decoder()))
  })
}

pub type ContainerData {
  ContainerData(
    id: String,
    names: List(String),
    image: String,
    image_id: String,
    command: String,
    created: Int,
    ports: List(Port),
    labels: dict.Dict(String, String),
    state: String,
    status: String,
    host_config: HostConfig,
    network_settings: dict.Dict(String, Network),
    mounts: List(Mount),
  )
}

fn container_data_decoder() -> decode.Decoder(ContainerData) {
  use id <- decode.field("Id", decode.string)
  use names <- decode.field("Names", decode.list(decode.string))
  use image <- decode.field("Image", decode.string)
  use image_id <- decode.field("ImageID", decode.string)
  use command <- decode.field("Command", decode.string)
  use created <- decode.field("Created", decode.int)
  use ports <- decode.field("Ports", decode.list(port_decoder()))
  use labels <- decode.field(
    "Labels",
    decode.dict(decode.string, decode.string),
  )
  use state <- decode.field("State", decode.string)
  use status <- decode.field("Status", decode.string)
  use host_config <- decode.field("HostConfig", host_config_decoder())
  use network_settings <- decode.subfield(
    ["NetworkSettings", "Networks"],
    decode.dict(decode.string, network_decoder()),
  )
  use mounts <- decode.field("Mounts", decode.list(mount_decoder()))
  decode.success(ContainerData(
    id:,
    names:,
    image:,
    image_id:,
    command:,
    created:,
    ports:,
    labels:,
    state:,
    status:,
    host_config:,
    network_settings:,
    mounts:,
  ))
}

pub type Port {
  /// IP ; PrivatePort ; PublicPort ; Type   ;;; in the json respectively
  Port(ip: String, private_port: Int, public_port: Int, port_type: String)
}

fn port_decoder() -> decode.Decoder(Port) {
  use ip <- decode.field("IP", decode.string)
  use private_port <- decode.field("PrivatePort", decode.int)
  use public_port <- decode.field("PublicPort", decode.int)
  use port_type <- decode.field("Type", decode.string)
  decode.success(Port(ip:, private_port:, public_port:, port_type:))
}

pub type HostConfig {
  HostConfig(network_mode: String, annotations: dict.Dict(String, String))
}

fn host_config_decoder() -> decode.Decoder(HostConfig) {
  use network_mode <- decode.field("NetworkMode", decode.string)
  use annotations <- decode.optional_field(
    "Annotations",
    dict.new(),
    decode.dict(decode.string, decode.string),
  )
  decode.success(HostConfig(network_mode:, annotations:))
}

pub type Network {
  Network(gateway: String, ip_address: String, ip_prefix_len: Int)
}

fn network_decoder() -> decode.Decoder(Network) {
  use gateway <- decode.field("Gateway", decode.string)
  use ip_address <- decode.field("IPAddress", decode.string)
  use ip_prefix_len <- decode.field("IPPrefixLen", decode.int)
  decode.success(Network(gateway:, ip_address:, ip_prefix_len:))
}

pub type Mount {
  Mount(
    mount_type: String,
    name: option.Option(String),
    source: String,
    destination: String,
    driver: option.Option(String),
    mode: String,
    rw: Bool,
    propagation: String,
  )
}

fn mount_decoder() -> decode.Decoder(Mount) {
  use mount_type <- decode.field("Type", decode.string)
  use name <- decode.optional_field(
    "Name",
    option.None,
    decode.optional(decode.string),
  )
  use source <- decode.field("Source", decode.string)
  use destination <- decode.field("Destination", decode.string)
  use driver <- decode.optional_field(
    "Driver",
    option.None,
    decode.optional(decode.string),
  )
  use mode <- decode.field("Mode", decode.string)
  use rw <- decode.field("RW", decode.bool)
  use propagation <- decode.field("Propagation", decode.string)
  decode.success(Mount(
    mount_type:,
    name:,
    source:,
    destination:,
    driver:,
    mode:,
    rw:,
    propagation:,
  ))
}
