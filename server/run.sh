watchexec --restart --verbose --wrap-process=session --stop-signal SIGTERM --exts gleam,mjs --debounce 500ms --watch ../shared/src/ --watch src/ -- "gleam run"
