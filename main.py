import flet as ft
from views.home import HomeView
from views.history import HistoryView
from views.settings import SettingsView

def main(page: ft.Page):
    page.title = "CaseGen"
    page.padding = 0
    page.bgcolor = "#e0e5ec" # Light gray background for contrast

    # Neo-brutalist theme colors
    color_primary = "#ff90e8" # Pink
    color_secondary = "#ffc900" # Yellow
    color_tertiary = "#00c4ff" # Cyan
    color_bg = "#ffffff"
    color_text = "#000000"

    # Styles
    shadow_color = ft.colors.BLACK
    border = ft.border.all(3, ft.colors.BLACK)

    # Views container
    content = ft.Container(
        expand=True,
        padding=20,
    )

    def route_change(e):
        page.views.clear()

        # Navigation bar
        nav_bar = ft.Container(
            content=ft.Row(
                [
                    ft.Text("CaseGen", size=24, weight=ft.FontWeight.W_900, color=color_text),
                    ft.Row(
                        [
                            nav_button("Home", "/", color_primary),
                            nav_button("History", "/history", color_secondary),
                            nav_button("Settings", "/settings", color_tertiary),
                        ],
                        alignment=ft.MainAxisAlignment.END,
                    )
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            ),
            padding=ft.padding.all(15),
            bgcolor=color_bg,
            border=ft.border.only(bottom=ft.BorderSide(3, ft.colors.BLACK)),
        )

        # Base view
        view = ft.View(
            route=page.route,
            controls=[
                nav_bar,
                content
            ],
            padding=0,
            bgcolor="#e0e5ec",
        )

        if page.route == "/":
            content.content = HomeView(page)
        elif page.route == "/history":
            content.content = HistoryView(page)
        elif page.route == "/settings":
            content.content = SettingsView(page)

        page.views.append(view)
        page.update()

    def nav_button(text, route, bgcolor):
        return ft.Container(
            content=ft.Text(text, weight=ft.FontWeight.BOLD, color=color_text),
            bgcolor=bgcolor,
            padding=ft.padding.symmetric(horizontal=15, vertical=10),
            border=border,
            border_radius=0,
            on_click=lambda _: page.go(route),
            shadow=ft.BoxShadow(
                spread_radius=0,
                blur_radius=0,
                color=shadow_color,
                offset=ft.Offset(3, 3),
            ),
            ink=True
        )

    page.on_route_change = route_change
    page.go("/")

if __name__ == '__main__':
    ft.app(target=main)
