defmodule JuliaBridge do
  use Rustler, otp_app: :julia_bridge, crate: "julia_bridge"

  # These functions are implemented in Rust
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  def multiply_array(_arr), do: :erlang.nif_error(:nif_not_loaded)
end
