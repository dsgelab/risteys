defmodule RisteysWeb.Live.RelationshipsTable do
  use RisteysWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:form, to_form(%{}))

    {:ok, socket, layout: false}
  end

  def handle_event("update_table", value, socket) do
    IO.inspect(value: value)
    {:noreply, socket}
  end

  def handle_event("sort_table", value, socket) do
    IO.inspect(value: value)
    {:noreply, socket}
  end

  defp sorter_buttons(column, form_id) do
    [
      Phoenix.HTML.Tag.content_tag(
        :button,
        "▲",
        name: "sorter",
        value: column <> "_asc",
        form: form_id,
        class: "radio-left"
      ),
      Phoenix.HTML.Tag.content_tag(
        :button,
        "▼",
        name: "sorter",
        value: column <> "_desc",
        form: form_id,
        class: "radio-right"
      )
  ]
  end
end
