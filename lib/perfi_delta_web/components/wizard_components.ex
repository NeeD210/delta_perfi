defmodule PerfiDeltaWeb.WizardComponents do
  @moduledoc """
  Componentes reutilizables para wizards (Onboarding y Cierre).
  Provee un layout consistente con indicador de pasos superior, contenido scrolleable
  y barra de navegación inferior fija.
  """
  use Phoenix.Component

  attr :steps, :list, required: true, doc: "Lista de pasos o número total de pasos"
  attr :current_step_index, :integer, required: true, doc: "Índice del paso actual (0-based)"
  attr :step_label_fn, :any, default: nil, doc: "Función para obtener label del paso. Si es nil, usa el valor del paso si es string."
  attr :can_go_back, :boolean, default: true
  attr :can_go_next, :boolean, default: true
  attr :next_label, :string, default: "Siguiente"
  attr :next_disabled, :boolean, default: false
  attr :finish_label, :string, default: "Finalizar"
  attr :on_next, :string, default: "next_step"
  attr :on_prev, :string, default: "prev_step"
  attr :on_finish, :string, default: nil
  attr :is_last_step, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def wizard_layout(assigns) do
    ~H"""
    <div class={["w-full max-w-lg mx-auto px-4 py-2 flex flex-col min-h-[calc(100dvh-5rem)] justify-between", @class]}>
      <!-- Progress Steps (fixed top relative to container) -->
      <.step_indicator
        steps={@steps}
        current_index={@current_step_index}
        label_fn={@step_label_fn}
      />

      <!-- Step Content (scrollable middle) -->
      <div class="flex-1 min-h-0 overflow-y-auto px-0 animate-fade-in py-2">
        <%= render_slot(@inner_block) %>
      </div>

      <!-- Navigation Buttons (fixed bottom relative to container) -->
      <.navigation_buttons
        can_go_back={@can_go_back}
        can_go_next={@can_go_next}
        next_label={@next_label}
        next_disabled={@next_disabled}
        finish_label={@finish_label}
        on_next={@on_next}
        on_prev={@on_prev}
        on_finish={@on_finish}
        is_last_step={@is_last_step}
        loading={@loading}
      />
    </div>
    """
  end

  attr :steps, :list, required: true
  attr :current_index, :integer, required: true
  attr :label_fn, :any

  def step_indicator(assigns) do
    # Normalizar steps a una lista si es un rango o número
    steps_list =
      if is_integer(assigns.steps) do
        1..assigns.steps |> Enum.to_list()
      else
        assigns.steps
      end

    assigns = assign(assigns, :steps_list, steps_list)
    total = length(steps_list)
    assigns = assign(assigns, :total, total)

    ~H"""
    <div class="flex justify-between items-center mb-0 flex-shrink-0">
      <%= for {step, index} <- Enum.with_index(@steps_list) do %>
        <div class={"flex items-center relative " <> if(index < @total - 1, do: "flex-1", else: "")}>
          <!-- Bubble/Indicator -->
          <div class={"z-10 flex items-center justify-center w-8 h-8 rounded-full transition-all duration-300 text-xs font-bold border-2
            #{cond do
              index < @current_index -> "bg-primary border-primary text-primary-content" # Past
              index == @current_index -> "bg-base-100 border-primary text-primary scale-110" # Current
              true -> "bg-base-100 border-base-300 text-base-content/30" # Future
            end}"}
          >
            <%= if index < @current_index do %>
              <span class="hero-check w-4 h-4"></span>
            <% else %>
              <%= index + 1 %>
            <% end %>
          </div>

          <!-- Connecting Line -->
          <%= if index < @total - 1 do %>
            <div class={"absolute left-0 top-1/2 -translate-y-1/2 w-full h-1 -z-0 ml-4 mr-[-1rem]
              #{if index < @current_index, do: "bg-primary", else: "bg-base-300"}"}
            ></div>
          <% end %>

          <!-- Label (Hidden on small screens, shown if fits) -->
          <div class="absolute top-10 left-1/2 -translate-x-1/2 whitespace-nowrap hidden sm:block">
            <span class={"text-[10px] font-medium tracking-wide transition-colors duration-300
              #{if index <= @current_index, do: "text-primary", else: "text-base-content/40"}"}
            >
              <%= get_label(step, @label_fn) %>
            </span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr :can_go_back, :boolean, required: true
  attr :can_go_next, :boolean, required: true
  attr :next_label, :string, required: true
  attr :next_disabled, :boolean, required: true
  attr :finish_label, :string, required: true
  attr :on_next, :string, required: true
  attr :on_prev, :string, required: true
  attr :on_finish, :string
  attr :is_last_step, :boolean, required: true
  attr :loading, :boolean, required: true

  def navigation_buttons(assigns) do
    ~H"""
    <div class="flex gap-3 mt-auto flex-shrink-0 border-t border-base-200 pt-2">
      <!-- Back Button -->
      <%= if @can_go_back do %>
        <button phx-click={@on_prev} class="btn btn-ghost flex-1 touch-target group">
          <span class="hero-arrow-left mr-2 group-hover:-translate-x-1 transition-transform"></span>
          Anterior
        </button>
      <% else %>
        <div class="flex-1"></div>
      <% end %>

      <!-- Next/Finish Button -->
      <%= if @is_last_step do %>
        <button
          phx-click={@on_finish || @on_next}
          class="btn btn-primary flex-1 touch-target shadow-lg shadow-primary/20"
          disabled={@next_disabled || @loading}
        >
          <%= if @loading do %>
            <span class="loading loading-spinner loading-xs mr-2"></span>
          <% else %>
            <span class="hero-check-circle mr-2"></span>
          <% end %>
          <%= @finish_label %>
        </button>
      <% else %>
        <button
          phx-click={@on_next}
          class="btn btn-primary flex-1 touch-target shadow-lg shadow-primary/20 group"
          disabled={@next_disabled || @loading}
        >
          <%= @next_label %>
          <span class="hero-arrow-right ml-2 group-hover:translate-x-1 transition-transform"></span>
        </button>
      <% end %>
    </div>
    """
  end

  defp get_label(step, nil) when is_binary(step), do: step
  defp get_label(step, nil) when is_atom(step), do: Phoenix.Naming.humanize(step)
  defp get_label(_step, nil), do: ""
  defp get_label(step, func) when is_function(func, 1), do: func.(step)
end
