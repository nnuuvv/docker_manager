import envoy
import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/erlang
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html
import mist.{type Connection, type ResponseData}
import shared/container
import shared/container_data.{type ContainerData}
import shared/element_state
import shared/node
import shared/virtual_machine
import shellout
import simplifile

pub fn main() -> Nil {
  let handler = fn(req: Request(Connection)) -> Response(ResponseData) {
    let path = request.path_segments(req)
    let method = req.method

    case method, path {
      Get, ["api", "node_data"] -> handle_get_node_data()
      Get, ["compose", ..rest] -> server_compose(rest)
      Post, ["compose", ..rest] -> write_compose(req, rest)
      Get, ["static", ..rest] -> serve_static(rest)
      Get, _ -> serve_app()

      _, _ ->
        response.new(404)
        |> response.set_body(mist.Bytes(bytes_tree.new()))
    }
  }

  let assert Ok(_) =
    mist.new(handler)
    |> mist.port(get_port())
    |> mist.bind("0.0.0.0")
    |> mist.start_http()

  process.sleep_forever()
  Nil
}

/// Gets the port from the `PORT` environment variable.
/// Defaults to 3000 if its not set.
///
fn get_port() -> Int {
  envoy.get("PORT")
  |> result.then(fn(port_string) { int.parse(port_string) })
  |> result.unwrap(3000)
}

fn serve_app() {
  //let containers = get_running_containers() |> result.unwrap([])

  let html =
    html.html(
      [
        attribute.styles([
          #("background-color", "#181414"),
          #("color", "#d8d4d4"),
        ]),
      ],
      [
        html.head([], [
          html.title([], "Docker manager"),
          html.link([
            attribute.href("/static/styles/main.css"),
            attribute.rel("stylesheet"),
          ]),
          html.script(
            [attribute.type_("module"), attribute.src("/static/client.mjs")],
            "",
          ),
        ]),
        html.body([], [html.div([attribute.id("app")], [])]),
      ],
    )

  response.new(200)
  |> response.set_body(
    html
    |> element.to_document_string()
    |> bytes_tree.from_string()
    |> mist.Bytes,
  )
}

// FILE SERVING -----------------------------------------------------------------------------

fn get_priv_dir() -> String {
  case erlang.priv_directory("server") {
    Ok(dir) -> dir
    Error(_) -> "./priv"
  }
}

fn serve_static(path_segments: List(String)) -> Response(ResponseData) {
  let file_path = string.join(path_segments, "/")

  let priv_dir = get_priv_dir()
  let full_path = string.concat([priv_dir, "/static/", file_path])

  case simplifile.read_bits(full_path) {
    Ok(content) -> {
      let content_type = determine_content_type(file_path)

      response.new(200)
      |> response.set_header("content-type", content_type)
      |> response.set_body(mist.Bytes(bytes_tree.from_bit_array(content)))
    }
    Error(_) -> {
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("File not found")))
    }
  }
}

fn determine_content_type(file_path: String) -> String {
  let is_javascript =
    string.ends_with(file_path, ".js") || string.ends_with(file_path, ".mjs")

  case is_javascript {
    True -> "application/javascript"
    False ->
      case string.ends_with(file_path, ".css") {
        True -> "text/css"
        False ->
          case string.ends_with(file_path, ".woff2") {
            True -> "font/woff2"
            False -> "text/plain"
          }
      }
  }
}

// COMPOSE FILE HANDLING ----------------------------------------------------------------------

fn server_compose(path_segments: List(String)) -> Response(ResponseData) {
  case list.first(path_segments) {
    Error(_) ->
      response.new(404)
      |> response.set_body(
        mist.Bytes(bytes_tree.from_string(
          "No container_name specified in /compose/container_name",
        )),
      )
    Ok(container_name) -> {
      let full_path = get_compose_path(container_name)

      case simplifile.read_bits(full_path) {
        Ok(content) -> {
          let content_type = determine_content_type(full_path)

          response.new(200)
          |> response.set_header("content-type", content_type)
          |> response.set_body(mist.Bytes(bytes_tree.from_bit_array(content)))
        }
        Error(_) -> {
          response.new(404)
          |> response.set_body(
            mist.Bytes(bytes_tree.from_string("File not found")),
          )
        }
      }
    }
  }
}

fn write_compose(
  req: Request(Connection),
  path_segments: List(String),
) -> Response(ResponseData) {
  case list.first(path_segments) {
    Error(_) ->
      response.new(404)
      |> response.set_body(
        mist.Bytes(bytes_tree.from_string(
          "No container_name specified in /compose/container_name",
        )),
      )
    Ok(container_name) -> {
      let full_path = get_compose_path(container_name)

      case
        result.try(request.get_header(req, "content-length"), fn(length) {
          use length <- result.try(int.parse(length))
          result.try(
            mist.read_body(req, length)
              |> result.replace_error(Nil),
            fn(body_bits) {
              simplifile.write_bits(to: full_path, bits: body_bits.body)
              |> result.replace_error(Nil)
            },
          )
        })
      {
        Error(_) -> {
          response.new(500)
          |> response.set_body(
            mist.Bytes(bytes_tree.from_string("Something went wrong")),
          )
        }
        Ok(_) ->
          response.new(200)
          |> response.set_body(
            mist.Bytes(bytes_tree.from_string("File updated successfully")),
          )
      }
    }
  }
}

/// Tries to get the compose path from the container associated with the supplied container_name
/// If we are running in an erlang shipment we assume we are running in the docker container named "docker_manager"
/// It will try to add the "com.docker.compose.project.working_dir" directory to itself to ensure its available 
/// If it cant find the working_dir it will return a path to `priv_dir/compose/container_name/docker-compose.yml`
///
fn get_compose_path(container_name: String) {
  let work_dir =
    try_get_compose_working_dir_from_container_labels(container_name)

  case work_dir {
    // we found an existing compose dir
    Ok(work_dir) -> {
      let compose_path =
        try_get_compose_path_from_container_labels(container_name)

      case compose_path {
        Ok(compose_path) -> compose_path
        Error(_) -> string.join([work_dir, "docker-compose.yml"], "/")
      }
    }
    // we didnt find an existing compose dir, use default
    Error(_) -> {
      string.join(
        [get_priv_dir(), "compose", container_name, "docker-compose.yml"],
        "/",
      )
    }
  }
}

fn try_get_compose_path_from_container_labels(container_name: String) {
  use shell_result <- result.try(
    shellout.command(
      run: "curl",
      with: [
        "--unix-socket",
        "/var/run/docker.sock",
        "--silent",
        "http:///v1.49/containers/" <> container_name <> "/json",
      ],
      in: ".",
      opt: [],
    )
    |> result.replace_error(json.UnexpectedEndOfInput),
  )

  json.parse(
    shell_result,
    decode.at(
      ["Config", "Labels", "com.docker.compose.project.config_files"],
      decode.string,
    ),
  )
}

fn try_get_compose_working_dir_from_container_labels(container_name: String) {
  use shell_result <- result.try(
    shellout.command(
      run: "curl",
      with: [
        "--unix-socket",
        "/var/run/docker.sock",
        "--silent",
        "http:///v1.49/containers/" <> container_name <> "/json",
      ],
      in: ".",
      opt: [],
    )
    |> result.replace_error(json.UnexpectedEndOfInput),
  )

  json.parse(
    shell_result,
    decode.at(
      ["Config", "Labels", "com.docker.compose.project.working_dir"],
      decode.string,
    ),
  )
}

// NODE DATA SERVING ----------------------------------------------------------------------------

fn handle_get_node_data() -> Response(ResponseData) {
  let containers =
    get_running_containers()
    |> option.from_result()
    |> option.map(fn(data) {
      data |> list.map(fn(data) { container.Container(data) })
    })
    |> node.Node("Main PC", _, option.None)

  let body =
    containers
    |> node.encode_node()
    |> json.to_string()
    |> bytes_tree.from_string()
    |> mist.Bytes

  response.new(200)
  |> response.set_body(body)
  |> response.set_header("content-type", "application/json")
}

fn get_running_containers() -> Result(List(ContainerData), json.DecodeError) {
  use shell_result <- result.try(
    shellout.command(
      run: "curl",
      with: [
        "--unix-socket", "/var/run/docker.sock", "--silent",
        "http:///v1.49/containers/json?all=true",
      ],
      in: ".",
      opt: [],
    )
    |> result.replace_error(json.UnexpectedEndOfInput),
  )

  json.parse(shell_result, decode.list(container_data.container_data_decoder()))
}
