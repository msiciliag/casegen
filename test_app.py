import asyncio
from unittest.mock import Mock

import pytest

import db
from main import main
from views.home import CASES


@pytest.fixture
def page(tmp_path, monkeypatch):
    monkeypatch.setattr(db, "DB_PATH", tmp_path / "history.db")
    page = Mock(route="/", views=[])

    def navigate(route):
        page.route = route
        page.on_route_change(None)

    page.go.side_effect = navigate
    main(page)
    return page


@pytest.mark.parametrize("key", CASES)
def test_library_to_reveal_and_history(page, key):
    case = CASES[key]
    library = page.views[-1].controls[-1].content
    button = next(c for c in library.controls if getattr(c, "text", None) == case["title"])
    button.on_click(None)
    view = page.views[-1].controls[-1].content
    answer, submit, result = view.controls[-3:]
    asyncio.run(submit.on_click(None))
    assert answer.error_text and not result.controls and not db.get_history()

    answer.value = "Probaría en un mercado primero."
    asyncio.run(submit.on_click(None))
    asyncio.run(submit.on_click(None))
    assert case["decision"] in [getattr(c, "value", None) for c in result.controls]
    assert case["outcome"] in [getattr(c, "value", None) for c in result.controls]
    assert {c.url for c in result.controls if getattr(c, "url", None)} == set(case["sources"].values())
    record, = db.get_history()
    assert record["solution"] == answer.value
    assert case["title"] in record["challenge"]

    page.go("/history")
    history = page.views[-1].controls[-1].content
    card, = history.controls[-1].controls
    assert card.content.controls[-1].value == answer.value
    db.delete_history(record["id"])
    assert not db.get_history()
