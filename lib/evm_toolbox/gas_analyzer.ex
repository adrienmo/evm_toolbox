defmodule EvmToolbox.GasAnalyzer do
  @moduledoc """
  Module to analyze the gas used by a given piece of code.
  It is injected in a forge project and then `forge test`
  is ran and the gas extracted
  """

  require Logger

  @versions 1..19

  @spec analyze(String.t(), fun(), fun()) :: :ok
  def analyze(code, result_callback, final_callback) do
    receiver = self()

    spawn(fn ->
      __MODULE__.do_analyze(code, receiver, result_callback)
      send(receiver, final_callback.())
    end)

    :ok
  end

  @spec do_analyze(String.t(), pid(), fun()) :: :ok
  def do_analyze(code, receiver, result_callback) do
    path = create_project(code)

    combinations = for version <- @versions, ir <- [true, false], do: {version, ir}

    Task.async_stream(
      combinations,
      fn {version, ir} ->
        {:ok, result} = analyze_version(version, ir, path)
        send(receiver, result_callback.({version, ir, result}))
      end,
      ordered: false,
      max_concurrency: 4,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp analyze_version(version, via_ir, path) do
    extra = if via_ir, do: ["--via-ir"], else: []

    {text, result} =
      System.cmd("forge", ["test", "--use", "0.8.#{version}", "--gas-report"] ++ extra, cd: path)

    parse(text, result)
  end

  defp parse(text, result) do
    0 = result

    gas =
      text
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "content"))
      |> List.last()
      |> String.split("|")
      |> Enum.at(3)
      |> String.trim()
      |> String.to_integer()

    {:ok, gas}
  rescue
    error ->
      Logger.error("parsing error: #{inspect({text, result, error})}")
      :error
  end

  defp create_project(code) do
    unique_id = :crypto.strong_rand_bytes(32) |> Base.encode16()
    path = "/tmp/builds/#{unique_id}/"
    File.mkdir_p!(path)
    zip_path = :code.priv_dir(:evm_toolbox) ++ '/code_wrapper.zip'
    :zip.extract(zip_path, [{:cwd, Kernel.to_charlist(path)}])

    path = path <> "code_wrapper"

    File.write(
      path <> "/src/CodeWrapper.sol",
      """
      // SPDX-License-Identifier: UNLICENSED
      pragma solidity ^0.8.0;

      contract CodeWrapper {
      function content() public {
      """ <>
        code <>
        """
            }
        }
        """
    )

    path
  end
end
