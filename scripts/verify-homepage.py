#!/usr/bin/env python3
"""Browser checks for the static site. Requires Python Playwright + Chromium.

Serve docs/ locally, then run:
  python3 scripts/verify-homepage.py --url http://127.0.0.1:8000 --output /tmp/openneko-web-qa
Use --browser-executable to test an installed Chrome instead of bundled Chromium.
"""

import argparse
import json
import re
from pathlib import Path
from urllib.parse import urlparse

from playwright.sync_api import expect, sync_playwright


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--browser-executable')
    parser.add_argument('--capture-only', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    report = {'checks': [], 'errors': [], 'failed_resources': []}

    def checked(name, condition=True):
        assert condition, name
        report['checks'].append(name)

    with sync_playwright() as playwright:
        launch = {'headless': True}
        if args.browser_executable:
            launch['executable_path'] = args.browser_executable
        browser = playwright.chromium.launch(**launch)
        try:
            context = browser.new_context(viewport={'width': 1440, 'height': 1000}, locale='en-US',
                device_scale_factor=1, permissions=['clipboard-read', 'clipboard-write'])
            page = context.new_page()
            page.on('pageerror', lambda error: report['errors'].append(str(error)))
            page.on('response', lambda response: report['failed_resources'].append(
                {'url': response.url, 'status': response.status}) if response.status >= 400 else None)
            page.add_init_script('''
                window.__nekoQa = {interval: 0, timeout: 0, raf: 0};
                for (const [name, kind] of [['setInterval', 'interval'], ['setTimeout', 'timeout'], ['requestAnimationFrame', 'raf']]) {
                    const original = window[name].bind(window);
                    window[name] = (callback, ...args) => original(typeof callback === 'function'
                        ? (...values) => { window.__nekoQa[kind]++; return callback(...values); }
                        : callback, ...args);
                }
            ''')
            page.goto(args.url, wait_until='networkidle')
            expect(page.locator('h1')).to_be_visible()
            page.evaluate('document.fonts.ready')
            page.screenshot(path=str(args.output / 'desktop-en.png'))
            if args.capture_only:
                return

            def timer_counts():
                start = page.evaluate('({...window.__nekoQa})')
                page.wait_for_timeout(1100)
                end = page.evaluate('({...window.__nekoQa})')
                return {key: end[key] - start[key] for key in start}

            requests_before_animation = page.evaluate('performance.getEntriesByType("resource").length')
            report['visible_callbacks_in_1100ms'] = timer_counts()
            checked('animation does not fetch additional frames', requests_before_animation == page.evaluate(
                'performance.getEntriesByType("resource").length'))
            page.evaluate('''
                Object.defineProperty(document, 'hidden', {configurable: true, get: () => true});
                document.dispatchEvent(new Event('visibilitychange'));
            ''')
            checked('hidden-page event stops repeating callbacks', sum(timer_counts().values()) == 0)
            page.evaluate('''
                delete document.hidden;
                document.dispatchEvent(new Event('visibilitychange'));
            ''')
            page.evaluate('window.scrollTo({top: document.body.scrollHeight, behavior: "instant"})')
            page.wait_for_timeout(400)
            report['offscreen_callbacks_in_1100ms'] = timer_counts()
            checked('offscreen animation has no repeating callbacks',
                sum(report['offscreen_callbacks_in_1100ms'].values()) == 0)

            # Visit the entire page before inspecting lazy images and recording resources.
            height = page.evaluate('document.body.scrollHeight')
            for y in range(0, height, 700):
                page.evaluate('(y) => window.scrollTo({top: y, behavior: "instant"})', y)
                page.wait_for_timeout(80)
            page.wait_for_load_state('networkidle')
            checked('all static images load', page.locator('img').evaluate_all(
                '(imgs) => imgs.every(img => img.complete && img.naturalWidth > 0)'))
            resources = page.evaluate('performance.getEntriesByType("resource").map(x => ({name: x.name, decodedBodySize: x.decodedBodySize}))')
            report['initial_resource_count'] = len(resources)
            report['initial_decoded_bytes'] = sum(item['decodedBodySize'] for item in resources)
            report['external_resources'] = [item['name'] for item in resources if urlparse(item['name']).netloc != urlparse(args.url).netloc]
            checked('no external font or script requests', not report['external_resources'])
            page.evaluate('window.scrollTo({top: 0, behavior: "instant"})')
            page.screenshot(path=str(args.output / 'full-page-en.png'), full_page=True)

            language = page.locator('#language-select')
            for lang in ['en', 'ko', 'ja', 'zh']:
                language.select_option(lang)
                checked(f'{lang} document language updates', page.locator('html').get_attribute('lang').split('-')[0] == lang)
                expect(language).to_have_value(lang)
                for width in [360, 390, 768, 1440]:
                    page.set_viewport_size({'width': width, 'height': 1000})
                    page.wait_for_timeout(100)
                    checked(f'{lang} layout fits {width}px', page.evaluate(
                        'document.documentElement.scrollWidth <= window.innerWidth'))
                page.screenshot(path=str(args.output / f'desktop-{lang}.png'))
                page.set_viewport_size({'width': 390, 'height': 844})
                page.screenshot(path=str(args.output / f'mobile-{lang}.png'))
            page.reload(wait_until='networkidle')
            expect(language).to_have_value('zh')
            checked('language preference survives reload')
            language.select_option('en')
            page.set_viewport_size({'width': 1440, 'height': 1000})

            for state in ['idle', 'typing', 'coding', 'success']:
                button = page.locator(f'button[data-state="{state}"]')
                button.click()
                expect(button).to_have_attribute('aria-pressed', 'true')
                checked(f'activity {state} selectable')
            for skin in ['classic', 'black', 'orange', 'calico', 'pink']:
                button = page.locator(f'button[data-skin="{skin}"]')
                button.click()
                expect(button).to_have_attribute('aria-pressed', 'true')
                page.locator('#desktop-demo').scroll_into_view_if_needed()
                folder = '' if skin == 'classic' else skin + '/'
                expect(page.locator('#cat-frames img:not([hidden])')).to_have_attribute(
                    'src', re.compile(r'^assets/sprites/' + folder + r'success_[0-3]\.png$'))
                checked(f'skin {skin} changes the preview')
            page.locator('button[data-skin="black"]').click()
            page.locator('#desktop-demo').scroll_into_view_if_needed()
            page.evaluate('''
                for (const skin of ['orange', 'classic', 'calico', 'pink', 'black']) {
                    document.querySelector(`button[data-skin="${skin}"]`).click();
                }
            ''')
            expect(page.locator('#cat-frames img:not([hidden])')).to_have_attribute(
                'src', re.compile(r'^assets/sprites/black/success_[0-3]\.png$'))
            checked('rapid skin changes keep the final selection')
            typing = page.locator('#typing-demo')
            typing.press_sequentially('hello neko', delay=30)
            expect(page.locator('button[data-state="typing"]')).to_have_attribute('aria-pressed', 'true')
            checked('typing triggers demo activity')
            page.locator('#pet-neko').click()
            checked('pet interaction keeps cat visible', page.locator('#cat-frames img').count() > 0)

            pause = page.locator('#motion-toggle')
            if pause.get_attribute('aria-pressed') != 'true':
                pause.click()
            expect(pause).to_have_attribute('aria-pressed', 'true')
            page.wait_for_timeout(1600)
            checked('pause stops repeating callbacks', sum(timer_counts().values()) == 0)

            page.locator('.source-install summary').click()
            page.locator('#copy-command').click()
            clipboard = page.evaluate('navigator.clipboard.readText()')
            checked('source command copies exactly', clipboard == page.locator('#install-command').inner_text())
            checked('download links point to latest macOS assets', page.locator('a[href*="releases/latest/download/"]').evaluate_all(
                '(links) => links.length >= 3 && links.every(a => /OpenNeko-macOS-Release\\.(dmg|zip)$/.test(a.href))'))
            checked('in-page links resolve', page.locator('a[href^="#"]').evaluate_all(
                '(links) => links.every(a => document.getElementById(a.getAttribute("href").slice(1)))'))
            page.keyboard.press('Control+Home')
            page.goto(args.url, wait_until='networkidle')
            page.keyboard.press('Tab')
            expect(page.locator('.skip-link')).to_be_focused()
            checked('keyboard skip link receives first focus')

            reduced = browser.new_context(viewport={'width': 390, 'height': 844}, reduced_motion='reduce')
            reduced_page = reduced.new_page()
            reduced_page.goto(args.url, wait_until='networkidle')
            expect(reduced_page.locator('#motion-toggle')).to_have_attribute('aria-pressed', 'true')
            checked('reduced motion starts paused')
            reduced_page.screenshot(path=str(args.output / 'reduced-motion.png'))
            reduced.close()

            static = browser.new_context(viewport={'width': 390, 'height': 844}, java_script_enabled=False)
            static_page = static.new_page()
            static_page.goto(args.url, wait_until='networkidle')
            expect(static_page.locator('h1')).to_be_visible()
            expect(static_page.locator('a[href$="OpenNeko-macOS-Release.dmg"]').first).to_be_visible()
            checked('no-JavaScript download and content work')
            static_page.screenshot(path=str(args.output / 'no-javascript.png'), full_page=True)
            static.close()
            checked('no browser exceptions', not report['errors'])
            checked('no missing resources', not report['failed_resources'])
            context.close()
        finally:
            browser.close()
            (args.output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
