import json
import sqlite3
from pathlib import Path

import flet as ft

from db import add_history


CASES = {
    path.stem: json.loads(path.read_text(encoding="utf-8"))
    for path in sorted((Path(__file__).resolve().parents[1] / "cases").glob("*.json"))
}


def HomeView(page):
    controls = [ft.Text("Biblioteca de casos", size=30, weight="bold")]
    for key, case in CASES.items():
        controls.extend([
            ft.Text(case["setting"]),
            ft.OutlinedButton(case["title"], on_click=lambda _, k=key: page.go(f"/caso/{k}")),
            ft.Divider(),
        ])
    return ft.Column(controls, scroll=ft.ScrollMode.AUTO)


def CaseView(page, case):
    answer = ft.TextField(label="Tu propuesta", multiline=True, min_lines=3)
    result = ft.Column()
    submit = ft.FilledButton("Guardar y ver el desenlace")

    async def save(_):
        if submit.disabled:
            return
        proposal = (answer.value or "").strip()
        if not proposal:
            answer.error_text = "Escribe qué harías antes de ver el desenlace."
            page.update()
            return
        try:
            add_history(case["title"] + "\n" + case["question"], proposal)
        except sqlite3.Error:
            answer.error_text = "No se pudo guardar. Tu propuesta sigue aquí para reintentarlo."
            page.update()
            return
        answer.error_text = None
        answer.read_only = True
        submit.disabled = True
        result.controls = [
            ft.Text("La decisión real", size=22, weight="bold"), ft.Text(case["decision"]),
            ft.Text("Qué ocurrió después", size=22, weight="bold"), ft.Text(case["outcome"]),
            ft.Text("Fuentes", weight="bold"),
            *(ft.TextButton(label, url=url) for label, url in case["sources"].items()),
            ft.OutlinedButton("Elegir otro caso", on_click=lambda _: page.go("/")),
        ]
        page.update()

    submit.on_click = save
    return ft.Column([
        ft.Text(case["setting"]), ft.Text(case["title"], size=30, weight="bold"),
        ft.Text(case["brief"], size=17), ft.Text(case["question"], weight="bold"),
        answer, submit, result,
    ], scroll=ft.ScrollMode.AUTO, spacing=14)
