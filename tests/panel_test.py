"""Browser regression tests. Requires Playwright and its Chromium browser."""
from pathlib import Path
import sys
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parent.parent
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, args=["--no-sandbox"])
    page = browser.new_page(viewport={"width": 400, "height": 560})
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.add_init_script("""
        window.messages = [];
        window.handlers = {};
        window.panel = {
            on: (name, fn) => { window.handlers[name] = fn; },
            post: (name, data) => { window.messages.push({name, data}); }
        };
    """)
    page.goto((root / "ui/map.html").as_uri())
    assert page.evaluate("window.messages[0].name") == "ready"
    page.evaluate("window.handlers.state({rooms:{A:{location:{x:1,y:1},exit_rooms:{B:'e'},normalized:{nw:'nw'},solved:false,visited:false,exits:false,thyngs:{mobs:{thugs:0,heavies:0,boss:0},players:{}}}},current_room:['A'],look_room:[],scry_room:[],trajectory_room:['A'],herd_path:{},is_in_medina:true,window_size:300,arrow_set:'default'})")
    page.wait_for_timeout(200)
    assert page.evaluate('Object.keys(arrowImages).length') == 8
    page.locator('#map-canvas').click(button='right', position={'x':50,'y':10})
    page.locator('#context-menu').get_by_text('Help', exact=True).click()
    assert page.evaluate('window.messages.at(-1).data.action') == 'help'
    assert not errors, errors
    if len(sys.argv) > 1:
        page.screenshot(path=sys.argv[1])
    browser.close()
print("PASS: panel rendering and actions")
