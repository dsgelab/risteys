defmodule RisteysWeb.DialogComponent do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal dialog.

  I created this one over the default modal to implement it using the HTML
  <dialog> tag, as it is now supported by all evergreen browsers.
  """
  attr :id, :string, required: true
  attr :corr_variants, :map, required: true
  slot :inner_block, required: true

  def modal_list_variants(assigns) do
    ~H"""
    <dialog
      id={@id}
      aria-labelledby={"#{@id}-label"}
      class="modal-dialog"
    >
      <button autofocus phx-click={hide_modal(@id)}  class="button-faded">Close</button>

      <h2 id={"#{@id}-label"}>Variant list</h2>

      <article>
        <article>
          <h3>Same direction of effect</h3>

          <%= if not Enum.empty?(@corr_variants.variants_same_dir) do %>
          <p>N coloc GWS hits:&nbsp;<%= length(@corr_variants.variants_same_dir) %></p>
          <p>Average relative Beta:&nbsp;<%= @corr_variants.beta_same_dir %></p>
          <table class="horizontal-table">
              <thead>
                  <tr>
                      <td>Variant</td>
                      <td>Closest genes</td>
                  </tr>
              </thead>
              <tbody>
                  <%= for {variant, genes} <- sort_variants(@corr_variants.variants_same_dir) do %>
                  <tr>
                      <td><%= RisteysWeb.CustomHTMLHelpers.ahref_extern("https://results.finngen.fi/variant/" <> variant, variant) %></td>
                      <td><%= list_genes(genes) %></td>
                  </tr>
                  <% end %>
              </tbody>
          </table>

          <% else %>
          <p>No data.</p>

          <% end %>
        </article>

        <article>
          <h3>Opposite direction of effect</h3>

          <%= if not Enum.empty?(@corr_variants.variants_opp_dir) do %>
          <p>N coloc GWS hits:&nbsp;<%= length(@corr_variants.variants_opp_dir) %></p>
          <p>Average relative Beta:&nbsp;<%= @corr_variants.beta_opp_dir %></p>
          <table class="horizontal-table">
              <thead>
                  <tr>
                      <td>Variant</td>
                      <td>Closest genes</td>
                  </tr>
              </thead>
              <tbody>
                  <%= for {variant, genes} <- sort_variants(@corr_variants.variants_opp_dir) do %>
                  <tr>
                      <td><%= RisteysWeb.CustomHTMLHelpers.ahref_extern("https://results.finngen.fi/variant/" <> variant, variant) %></td>
                      <td><%= list_genes(genes) %></td>
                  </tr>
                  <% end %>
              </tbody>
          </table>

          <% else %>
          <p>No data.</p>
          <% end %>
        </article>
      </article>
    </dialog>
    """
  end

  def show_modal(id) do
    JS.dispatch("show-modal", to: "##{id}")
  end

  defp hide_modal(id) do
    JS.dispatch("hide-modal", to: "##{id}")
  end

  defp sort_variants(variants) do
    # Sort variant by CHR, POS.
    Enum.sort_by(variants, fn {variant, _genes} ->
      [chr, pos, _ref, _alt] = String.split(variant, "-")
      chr = String.to_integer(chr)
      pos = String.to_integer(pos)
      [chr, pos]
    end)
  end

  defp list_genes(genes) do
    genes
    |> Enum.map(fn gene -> gene.name end)
    |> Enum.map(fn name -> RisteysWeb.CustomHTMLHelpers.ahref_extern("https://results.finngen.fi/gene/" <> name, name) end)
    |> Enum.intersperse(", ")
  end
end
