import flet as ft

from db import init_db
from views.history import HistoryView
from views.home import CASES, CaseView, HomeView


def main(page: ft.Page):
    init_db()
    page.title = "CaseGen"
    page.theme_mode = ft.ThemeMode.LIGHT

    def route_change(_):
        case = CASES.get(page.route.removeprefix("/caso/")) if page.route.startswith("/caso/") else None
        if case:
            content = CaseView(page, case)
        elif page.route == "/history":
            content = HistoryView(page)
        else:
            content = HomeView(page)
        nav = ft.Row([
            ft.Text("CaseGen", size=22, weight="bold"),
            ft.TextButton("Biblioteca", on_click=lambda _: page.go("/")),
            ft.TextButton("Historial", on_click=lambda _: page.go("/history")),
        ], wrap=True)
        page.views.clear()
        page.views.append(ft.View(page.route, [nav, ft.Divider(), ft.Container(content, expand=True)], padding=20))
        page.update()

    page.on_route_change = route_change
    page.go(page.route)


if __name__ == "__main__":
    ft.app(target=main)
