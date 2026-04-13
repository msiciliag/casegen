import flet as ft
from db import get_api_key, set_api_key

def SettingsView(page: ft.Page):

    api_key_input = ft.TextField(
        label="Gemini API Key",
        value=get_api_key(),
        password=True,
        can_reveal_password=True,
        border_color=ft.colors.BLACK,
        border_width=3,
        border_radius=0,
        bgcolor=ft.colors.WHITE,
        color=ft.colors.BLACK,
        expand=True
    )

    def save_clicked(e):
        set_api_key(api_key_input.value)

        # Show a quick neo-brutalist snackbar
        snack = ft.SnackBar(
            content=ft.Text("API Key Saved!", color=ft.colors.BLACK, weight=ft.FontWeight.BOLD),
            bgcolor="#ffc900",
            duration=2000,
            # No real way to add border/shadow to snackbar directly in standard Flet,
            # but the bright color fits the theme.
        )
        page.overlay.append(snack)
        snack.open = True
        page.update()

    save_btn = ft.Container(
        content=ft.Text("SAVE SETTINGS", weight=ft.FontWeight.W_900, size=16, color=ft.colors.BLACK),
        bgcolor="#00c4ff",
        padding=ft.padding.symmetric(horizontal=30, vertical=15),
        border=ft.border.all(3, ft.colors.BLACK),
        border_radius=0,
        on_click=save_clicked,
        shadow=ft.BoxShadow(
            spread_radius=0,
            blur_radius=0,
            color=ft.colors.BLACK,
            offset=ft.Offset(4, 4),
        ),
        ink=True
    )

    container = ft.Container(
        content=ft.Column(
            [
                ft.Text("Settings", size=32, weight=ft.FontWeight.W_900, color=ft.colors.BLACK),
                ft.Container(height=20),
                ft.Text("Enter your generative model API key below. This is required to generate new business challenges.", color=ft.colors.BLACK),
                ft.Container(height=10),
                ft.Row([api_key_input]),
                ft.Container(height=20),
                save_btn
            ]
        ),
        bgcolor=ft.colors.WHITE,
        padding=30,
        border=ft.border.all(3, ft.colors.BLACK),
        border_radius=0,
        shadow=ft.BoxShadow(
            spread_radius=0,
            blur_radius=0,
            color=ft.colors.BLACK,
            offset=ft.Offset(8, 8),
        ),
        width=600,
    )

    return ft.Column([container], alignment=ft.MainAxisAlignment.CENTER, horizontal_alignment=ft.CrossAxisAlignment.CENTER)
