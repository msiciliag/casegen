import flet as ft
from ai import generate_challenge
from db import get_api_key, add_history

def HomeView(page: ft.Page):

    challenge_text = ft.Text(
        "No challenge generated yet.\nPress the button below to start.",
        size=16,
        color=ft.colors.BLACK,
        selectable=True
    )

    solution_input = ft.TextField(
        multiline=True,
        min_lines=10,
        max_lines=20,
        label="Write your solution here...",
        border_color=ft.colors.BLACK,
        border_width=3,
        border_radius=0,
        bgcolor=ft.colors.WHITE,
        color=ft.colors.BLACK,
        expand=True
    )

    loading_indicator = ft.ProgressRing(visible=False, color=ft.colors.BLACK)

    def show_snack(message, color):
        snack = ft.SnackBar(content=ft.Text(message, color=ft.colors.BLACK, weight=ft.FontWeight.BOLD), bgcolor=color)
        page.overlay.append(snack)
        snack.open = True
        page.update()

    def generate_clicked(e):
        api_key = get_api_key()
        if not api_key:
            show_snack("Please set your API Key in Settings first.", "#ff90e8")
            return

        loading_indicator.visible = True
        gen_btn.disabled = True
        page.update()

        try:
            challenge = generate_challenge(api_key)
            challenge_text.value = challenge
            solution_input.value = ""
        except Exception as ex:
            challenge_text.value = f"Error generating challenge: {str(ex)}"

        loading_indicator.visible = False
        gen_btn.disabled = False
        page.update()

    def save_clicked(e):
        if not challenge_text.value or challenge_text.value.startswith("No challenge") or challenge_text.value.startswith("Error"):
            show_snack("Nothing to save yet.", "#ff90e8")
            return

        if not solution_input.value:
            show_snack("Please write a solution before saving.", "#ff90e8")
            return

        add_history(challenge_text.value, solution_input.value)
        show_snack("Case and solution saved to History!", "#ffc900")

    gen_btn = ft.Container(
        content=ft.Row([ft.Text("GENERATE CHALLENGE", weight=ft.FontWeight.W_900, size=16, color=ft.colors.BLACK), loading_indicator], alignment=ft.MainAxisAlignment.CENTER),
        bgcolor="#ff90e8", # Pink
        padding=ft.padding.symmetric(horizontal=30, vertical=15),
        border=ft.border.all(3, ft.colors.BLACK),
        border_radius=0,
        on_click=generate_clicked,
        shadow=ft.BoxShadow(spread_radius=0, blur_radius=0, color=ft.colors.BLACK, offset=ft.Offset(4, 4)),
        ink=True,
        width=300
    )

    save_btn = ft.Container(
        content=ft.Text("SAVE SOLUTION", weight=ft.FontWeight.W_900, size=16, color=ft.colors.BLACK),
        bgcolor="#00c4ff", # Cyan
        padding=ft.padding.symmetric(horizontal=30, vertical=15),
        border=ft.border.all(3, ft.colors.BLACK),
        border_radius=0,
        on_click=save_clicked,
        shadow=ft.BoxShadow(spread_radius=0, blur_radius=0, color=ft.colors.BLACK, offset=ft.Offset(4, 4)),
        ink=True,
        width=300
    )

    challenge_container = ft.Container(
        content=ft.Column([
            ft.Text("THE CHALLENGE", size=24, weight=ft.FontWeight.W_900, color=ft.colors.BLACK),
            ft.Container(height=10),
            challenge_text
        ], scroll=ft.ScrollMode.AUTO),
        bgcolor=ft.colors.WHITE,
        padding=30,
        border=ft.border.all(3, ft.colors.BLACK),
        border_radius=0,
        shadow=ft.BoxShadow(spread_radius=0, blur_radius=0, color=ft.colors.BLACK, offset=ft.Offset(8, 8)),
        expand=True
    )

    solution_container = ft.Container(
        content=ft.Column([
            ft.Text("YOUR PROPOSAL", size=24, weight=ft.FontWeight.W_900, color=ft.colors.BLACK),
            ft.Container(height=10),
            solution_input,
            ft.Container(height=10),
            ft.Row([save_btn], alignment=ft.MainAxisAlignment.END)
        ]),
        bgcolor=ft.colors.WHITE,
        padding=30,
        border=ft.border.all(3, ft.colors.BLACK),
        border_radius=0,
        shadow=ft.BoxShadow(spread_radius=0, blur_radius=0, color=ft.colors.BLACK, offset=ft.Offset(8, 8)),
        expand=True
    )

    return ft.Column([
        ft.Row([gen_btn], alignment=ft.MainAxisAlignment.CENTER),
        ft.Container(height=20),
        ft.Row([
            challenge_container,
            ft.Container(width=20),
            solution_container
        ], expand=True, vertical_alignment=ft.CrossAxisAlignment.START)
    ], expand=True)
