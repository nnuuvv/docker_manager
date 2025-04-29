import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/option

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

pub fn encode_container_list(containers: List(ContainerData)) -> json.Json {
  json.array(containers, encode_container_data)
}

pub fn encode_container_data(container_data: ContainerData) -> json.Json {
  let ContainerData(
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
  ) = container_data
  json.object([
    #("Id", json.string(id)),
    #("Names", json.array(names, json.string)),
    #("Image", json.string(image)),
    #("ImageID", json.string(image_id)),
    #("Command", json.string(command)),
    #("Created", json.int(created)),
    #("Ports", json.array(ports, encode_port)),
    #("Labels", json.dict(labels, fn(string) { string }, json.string)),
    #("State", json.string(state)),
    #("Status", json.string(status)),
    #("HostConfig", encode_host_config(host_config)),
    #(
      "NetworkSettings",
      json.object([
        #(
          "Networks",
          json.dict(network_settings, fn(string) { string }, encode_network),
        ),
      ]),
    ),
    #("Mounts", json.array(mounts, encode_mount)),
  ])
}

pub fn container_data_decoder() -> decode.Decoder(ContainerData) {
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
  Port(
    ip: option.Option(String),
    private_port: option.Option(Int),
    public_port: option.Option(Int),
    port_type: option.Option(String),
  )
}

fn encode_port(port: Port) -> json.Json {
  let Port(ip:, private_port:, public_port:, port_type:) = port
  json.object([
    #("IP", case ip {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("PrivatePort", case private_port {
      option.None -> json.null()
      option.Some(value) -> json.int(value)
    }),
    #("PublicPort", case public_port {
      option.None -> json.null()
      option.Some(value) -> json.int(value)
    }),
    #("Type", case port_type {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
  ])
}

fn port_decoder() -> decode.Decoder(Port) {
  use ip <- decode.optional_field(
    "IP",
    option.None,
    decode.optional(decode.string),
  )
  use private_port <- decode.optional_field(
    "PrivatePort",
    option.None,
    decode.optional(decode.int),
  )
  use public_port <- decode.optional_field(
    "PublicPort",
    option.None,
    decode.optional(decode.int),
  )
  use port_type <- decode.optional_field(
    "Type",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(Port(ip:, private_port:, public_port:, port_type:))
}

pub type HostConfig {
  HostConfig(network_mode: String, annotations: dict.Dict(String, String))
}

fn encode_host_config(host_config: HostConfig) -> json.Json {
  let HostConfig(network_mode:, annotations:) = host_config
  json.object([
    #("NetworkMode", json.string(network_mode)),
    #("Annotations", json.dict(annotations, fn(string) { string }, json.string)),
  ])
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

fn encode_network(network: Network) -> json.Json {
  let Network(gateway:, ip_address:, ip_prefix_len:) = network
  json.object([
    #("Gateway", json.string(gateway)),
    #("IPAddress", json.string(ip_address)),
    #("IPPrefixLen", json.int(ip_prefix_len)),
  ])
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

fn encode_mount(mount: Mount) -> json.Json {
  let Mount(
    mount_type:,
    name:,
    source:,
    destination:,
    driver:,
    mode:,
    rw:,
    propagation:,
  ) = mount
  json.object([
    #("Type", json.string(mount_type)),
    #("Name", case name {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("Source", json.string(source)),
    #("Destination", json.string(destination)),
    #("Driver", case driver {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("Mode", json.string(mode)),
    #("RW", json.bool(rw)),
    #("Propagation", json.string(propagation)),
  ])
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
