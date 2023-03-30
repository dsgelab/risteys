defmodule RisteysWeb.ViewHelpers do
	alias Phoenix.HTML.Tag

	def ahref_feedback(conn, content) do
		where_from = Phoenix.Controller.current_path(conn)
		href = "https://airtable.com/shrTzTwby7JhFEqi6?prefill_Page=" <> where_from
		Tag.content_tag(:a, content, target: "_blank", rel: "noopener noreferrer external", href: href)
	end
end
