import flet as ft
from db import get_history, delete_history

def HistoryView(page: ft.Page):

    history_list = ft.ListView(expand=True, spacing=20)

    def load_history():
        history_list.controls.clear()
        records = get_history()

        if not records:
            history_list.controls.append(
                ft.Text("Aquí aparecerán tus propuestas guardadas.", size=18, color=ft.colors.BLACK)
            )
            return

        for record in records:
            history_list.controls.append(create_history_card(record))

    def create_history_card(record):

        def del_clicked(e):
            delete_history(record['id'])
            load_history()
            page.update()

        del_btn = ft.Container(
            content=ft.Text("Borrar", weight=ft.FontWeight.W_900, size=12, color=ft.colors.BLACK),
            bgcolor="#ff90e8",
            padding=ft.padding.symmetric(horizontal=15, vertical=5),
            border=ft.border.all(2, ft.colors.BLACK),
            border_radius=0,
            on_click=del_clicked,
            shadow=ft.BoxShadow(spread_radius=0, blur_radius=0, color=ft.colors.BLACK, offset=ft.Offset(2, 2)),
            ink=True,
        )

        return ft.Container(
            content=ft.Column([
                ft.Row([
                    ft.Text(f"Intento {record['id']} - {record['timestamp']}", weight=ft.FontWeight.W_900, size=18, color=ft.colors.BLACK),
                    del_btn
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                ft.Divider(color=ft.colors.BLACK, thickness=2),
                ft.Text("Caso", weight=ft.FontWeight.BOLD, color=ft.colors.BLACK),
                ft.Text(record['challenge'], color=ft.colors.BLACK, size=14, selectable=True),
                ft.Container(height=10),
                ft.Text("Tu propuesta", weight=ft.FontWeight.BOLD, color=ft.colors.BLACK),
                ft.Text(record['solution'], color=ft.colors.BLACK, size=14, selectable=True),
            ]),
            bgcolor=ft.colors.WHITE,
            padding=20,
            border=ft.border.all(3, ft.colors.BLACK),
            border_radius=0,
            shadow=ft.BoxShadow(spread_radius=0, blur_radius=0, color=ft.colors.BLACK, offset=ft.Offset(6, 6)),
        )

    load_history()

    return ft.Column([
        ft.Text("Historial", size=32, weight=ft.FontWeight.W_900, color=ft.colors.BLACK),
        ft.Container(height=20),
        history_list
    ], expand=True)
