import container_data.{type ContainerData}
import envoy
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/pair
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html
import mist.{type Connection, type ResponseData}
import shellout
import simplifile

pub fn main() -> Nil {
  let handler = fn(req: Request(Connection)) -> Response(ResponseData) {
    let path = request.path_segments(req)
    let method = req.method

    case method, path {
      Get, ["api", "container_data"] -> handle_get_container_data()
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
    html.html([], [
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
    ])

  response.new(200)
  |> response.set_body(
    html
    |> element.to_document_string()
    |> bytes_tree.from_string()
    |> mist.Bytes,
  )
}

fn serve_static(path_segments: List(String)) -> Response(ResponseData) {
  let file_path = string.join(path_segments, "/")
  let priv_dir = "./priv"

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
        False -> "text/plain"
      }
  }
}

fn handle_get_container_data() -> Response(ResponseData) {
  let containers = get_running_containers()

  case containers {
    Error(_) ->
      response.new(500)
      |> response.set_body(
        mist.Bytes(bytes_tree.from_string("Failed to get container data")),
      )
    Ok(containers) -> {
      let body =
        containers
        |> json.array(container_data.encode_container_data)
        |> json.to_string()
        |> bytes_tree.from_string()
        |> mist.Bytes

      response.new(200)
      |> response.set_body(body)
      |> response.set_header("content-type", "application/json")
    }
  }
}

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
    json.parse(data_json, decode.list(container_data.container_data_decoder()))
  })
}
