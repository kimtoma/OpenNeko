#!/usr/bin/env python3
"""Check the local sprite review's five skins, 4-frame loops and backgrounds."""
import argparse
import json
import re
from pathlib import Path
from urllib.parse import urlparse
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url', required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--browser-executable', required=True)
parser.add_argument('--new-frame-size', type=int, default=128,
                    help='Intrinsic PNG size for the new artwork, e.g. 256 or 1024.')
parser.add_argument('--old-frame-size', type=int, default=128,
                    help='Intrinsic PNG size of the comparison artwork.')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
states = ['idle', 'hover', 'click', 'coding', 'typing', 'thinking', 'lunch',
          'yawn', 'nap', 'success', 'error', 'dragging', 'walk', 'jump']
skins = ['default', 'black', 'orange', 'calico', 'pink']
report = {'checks': [], 'errors': [], 'failed_resources': [],
          'failed_requests': [], 'aborted_requests': [], 'captures': {}, 'passed': False}
expected = {'version': 'new', 'skin': 'default', 'frame': 0}


def expect_images(version, skin, frame):
    expected.update(version=version, skin=skin, frame=frame)


def is_expected_request(url):
    path = urlparse(url).path
    if '/app-sprites/' not in path and any(path.endswith(f'/{skin}/idle_0.png') for skin in skins):
        return True  # The five visible skin thumbnails always use the new idle frame.
    frames = range(4) if expected['frame'] is None else [expected['frame']]
    folder = expected['skin'] + '/'
    if expected['version'] == 'old':
        folder = '/app-sprites/' + ('' if expected['skin'] == 'default' else folder)
    else:
        if '/app-sprites/' in path:
            return False
        folder = '/' + folder
    return any(path.endswith(f'{folder}{state}_{frame}.png')
               for state in states for frame in frames)


def record_request_failure(request):
    failure = {'url': request.url, 'error': request.failure,
               'resource_type': request.resource_type}
    if request.failure == 'net::ERR_ABORTED':
        failure['superseded'] = request.resource_type == 'image' and not is_expected_request(request.url)
        report['aborted_requests'].append(failure)
    else:
        report['failed_requests'].append(failure)


def image_snapshot(page, selector='.gallery img'):
    return page.locator(selector).evaluate_all('''imgs => imgs.map(img => ({
        state: img.dataset.state, src: img.getAttribute('src'), currentSrc: img.currentSrc,
        skin: img.closest('[data-skin]')?.dataset.skin,
        complete: img.complete, naturalWidth: img.naturalWidth, naturalHeight: img.naturalHeight
    }))''')


def wait_for_images(page, label):
    target = {**expected, 'states': states, 'skins': skins, 'thumbnailSize': args.new_frame_size,
              'size': args.new_frame_size if expected['version'] == 'new' else args.old_frame_size}
    page.wait_for_function('''target => {
        const imgs = [...document.querySelectorAll('.gallery img')];
        if (imgs.length !== target.states.length ||
            new Set(imgs.map(img => img.dataset.state)).size !== target.states.length) return false;
        const thumbnails = [...document.querySelectorAll('.skins img')];
        if (thumbnails.length !== target.skins.length || !thumbnails.every(img => {
            const skin = img.closest('[data-skin]')?.dataset.skin;
            const src = `./${skin}/idle_0.png`;
            return target.skins.includes(skin) && img.getAttribute('src') === src &&
                img.currentSrc === new URL(src, document.baseURI).href && img.complete &&
                img.naturalWidth === target.thumbnailSize && img.naturalHeight === target.thumbnailSize;
        })) return false;
        return imgs.every(img => {
            const state = img.dataset.state;
            const file = `${state}_${target.frame}.png`;
            const src = img.getAttribute('src') || '';
            const oldFolder = target.skin === 'default' ? '' : `${target.skin}/`;
            const sourceMatches = target.version === 'new'
                ? src === `./${target.skin}/${file}`
                : src.includes('/app-sprites/') && src.split('/app-sprites/').pop() === `${oldFolder}${file}`;
            return target.states.includes(state) && sourceMatches &&
                img.currentSrc === new URL(src, document.baseURI).href && img.complete &&
                img.naturalWidth === target.size && img.naturalHeight === target.size;
        });
    }''', arg=target)
    assert not report['failed_requests'], report['failed_requests']
    assert not report['failed_resources'], report['failed_resources']
    assert page.locator('#status').inner_text() == f"프레임 {expected['frame'] + 1} / 4", label


with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path=args.browser_executable)
    page = None
    try:
        page = browser.new_page(viewport={'width': 1440, 'height': 1000},
                                device_scale_factor=1, reduced_motion='reduce')
        page.on('pageerror', lambda e: report['errors'].append(str(e)))
        page.on('response', lambda r: report['failed_resources'].append(r.url) if r.status >= 400 else None)
        page.on('requestfailed', record_request_failure)
        page.goto(args.url, wait_until='networkidle')
        assert page.locator('#play').get_attribute('aria-pressed') == 'false'
        report['checks'].append('reduced-motion starts paused')
        for version in ['new', 'old']:
            expect_images(version, expected['skin'], 0)
            page.select_option('#version', version)
            for skin in skins:
                expect_images(version, skin, 0)
                page.locator(f'[data-skin="{skin}"]').click()
                for frame in range(4):
                    expect_images(version, skin, frame)
                    wait_for_images(page, f'{version}:{skin}:frame{frame}')
                    report['checks'].append(f'{version}:{skin}:frame{frame}:14 states load')
                    expect_images(version, skin, (frame + 1) % 4)
                    page.locator('#step').click()
        expect_images('new', expected['skin'], 0)
        page.select_option('#version', 'new')
        expect_images('new', 'default', 0)
        page.locator('[data-skin="default"]').click()
        wait_for_images(page, 'layout start')
        for width in [360, 768, 1440]:
            page.set_viewport_size({'width': width, 'height': 1000})
            for scale in ['64', '128', '256']:
                page.select_option('#scale', scale)
                assert page.locator('.gallery img').first.evaluate('(i) => i.getBoundingClientRect().width') == int(scale)
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), (width, scale)
                report['checks'].append(f'layout:{width}:art{scale}:no overflow')
        page.set_viewport_size({'width': 1440, 'height': 1000})
        page.select_option('#scale', '128')
        for background in ['checker', 'white', 'dark', 'mint']:
            page.select_option('#background', background)
            assert page.locator('.gallery').get_attribute('data-bg') == background
            report['checks'].append(f'background:{background}')
        page.select_option('#background', 'dark')
        wait_for_images(page, 'desktop screenshot')
        report['captures']['desktop'] = {'expected': dict(expected), 'images': image_snapshot(page),
                                         'thumbnails': image_snapshot(page, '.skins img')}
        page.screenshot(path=str(args.output / 'review-desktop.png'), full_page=True)
        expect_images('new', 'default', None)
        page.locator('#play').click()
        page.wait_for_timeout(300)
        page.locator('#play').click()
        assert page.locator('#play').get_attribute('aria-pressed') == 'false'
        status = re.fullmatch(r'프레임 ([1-4]) / 4', page.locator('#status').inner_text())
        assert status and status.group(1) != '1', page.locator('#status').inner_text()
        expect_images('new', 'default', int(status.group(1)) - 1)
        wait_for_images(page, 'paused animation')
        report['checks'].append('play advances frames and pause works')
        page.set_viewport_size({'width': 390, 'height': 844})
        wait_for_images(page, 'mobile screenshot')
        report['captures']['mobile'] = {'expected': dict(expected), 'images': image_snapshot(page),
                                        'thumbnails': image_snapshot(page, '.skins img')}
        page.screenshot(path=str(args.output / 'review-mobile.png'), full_page=True)
        page.wait_for_load_state('networkidle')
        assert not report['errors'], report['errors']
        assert not report['failed_resources'], report['failed_resources']
        assert not report['failed_requests'], report['failed_requests']
        report['passed'] = True
    except Exception as error:
        report['failure'] = {'message': str(error), 'expected': dict(expected)}
        if page is not None:
            try:
                report['failure']['images'] = image_snapshot(page)
                report['failure']['thumbnails'] = image_snapshot(page, '.skins img')
                page.screenshot(path=str(args.output / 'failure.png'), full_page=True)
            except Exception as capture_error:
                report['failure']['capture_error'] = str(capture_error)
        raise
    finally:
        browser.close()
        (args.output / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False))
print(json.dumps({'checks_passed': len(report['checks']), 'errors': report['errors'],
                  'failed_resources': report['failed_resources'], 'failed_requests': report['failed_requests'],
                  'aborted_requests': report['aborted_requests'], 'passed': report['passed']}, ensure_ascii=False))
