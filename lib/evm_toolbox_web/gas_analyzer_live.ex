defmodule EvmToolboxWeb.GasAnalyzerLive do
  use EvmToolboxWeb, :live_view

  alias EvmToolbox.GasAnalyzer

  require Logger

  def mount(_params, _session, socket) do
    {:ok, assign(socket, code: "uint i;\ni++;", db: %{}, result: [], enabled: true)}
  end

  def handle_event("submit", params, socket) do
    code = params["code"]
    GasAnalyzer.analyze(code, fn result -> {:new_result, result} end, fn -> :finished end)
    {:noreply, assign(socket, code: code, enabled: false, db: %{})}
  end

  def handle_info({:new_result, {version, ir, result}}, %{assigns: %{db: db}} = socket) do
    db = Map.update(db, version, %{ir => result}, fn truc -> Map.put(truc, ir, result) end)
    result = db_to_result(db)
    {:noreply, assign(socket, db: db, result: result)}
  end

  def handle_info(:finished, socket) do
    {:noreply, assign(socket, enabled: true)}
  end

  def db_to_result(db) do
    Enum.map(db, fn {version, data} ->
      {"0.8.#{version}", data[false], data[true]}
    end)
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Gas Analyzer</h1>
      <div class="grid grid-cols-2 gap-4">
        <div>
          <form class="m-0 flex space-x-2" phx-submit="submit">
            <div>
              <div>
                <textarea
                  disabled={not @enabled}
                  class="block w-full h-48 p-2.5 bg-gray-50 border border-gray-300 text-gray-900 text-sm"
                  name="code"
                  phx-debounce="300"
                  value={@code}
                ><%= @code %></textarea>
              </div>
              <div>
                <button
                  class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
                  disabled={not @enabled}
                >
                  Analyze
                </button>
              </div>
            </div>
          </form>
        </div>
        <div>
          <div class="relative overflow-x-auto shadow-md sm:rounded-lg">
            <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
              <thead class="text-xs text-gray-700 uppercase dark:text-gray-400">
                <tr>
                  <th scope="col" class="px-6 py-3 bg-gray-50 dark:bg-gray-800">Solc version</th>
                  <th scope="col" class="px-6 py-3">GAS</th>
                  <th scope="col" class="px-6 py-3">GAS IR</th>
                </tr>
              </thead>
              <tbody>
                <%= for {key, value, value2} <- @result do %>
                  <tr class="border-b border-gray-200 dark:border-gray-700">
                    <th
                      scope="row"
                      class="px-6 py-4 font-medium text-gray-900 whitespace-nowrap bg-gray-50 dark:text-white dark:bg-gray-800"
                    >
                      <%= key %>
                    </th>
                    <td><%= inspect(value) %></td>
                    <td><%= inspect(value2) %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
