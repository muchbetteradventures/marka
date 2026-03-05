import Foundation

extension HTMLTemplate {
    static let appScriptBlock: String = #"""
<script>
// Configure marked with highlight.js
const {markedHighlight} = globalThis.markedHighlight;
marked.use(markedHighlight({
    langPrefix: 'hljs language-',
    highlight(code, lang) {
        if (lang && hljs.getLanguage(lang)) {
            return hljs.highlight(code, { language: lang }).value;
        }
        return code;
    }
}));

marked.use({
    gfm: true,
    breaks: false
});

function updateMarkdown(md) {
    document.getElementById('content').innerHTML = marked.parse(md);
}

// --- Find in page ---

(function() {
    var findBar = null;
    var findInput = null;
    var countDisplay = null;
    var matches = [];
    var currentMatch = -1;
    var originalContent = '';

    function createFindBar() {
        findBar = document.createElement('div');
        findBar.id = 'marka-find';
        findBar.innerHTML = `
            <input type="text" placeholder="Find..." spellcheck="false" autocomplete="off">
            <span class="marka-find-count"></span>
            <button data-dir="prev">\u25B2</button>
            <button data-dir="next">\u25BC</button>
            <button data-dir="close">\u2715</button>
        `;
        document.body.insertBefore(findBar, document.body.firstChild);
        findInput = findBar.querySelector('input');
        countDisplay = findBar.querySelector('.marka-find-count');

        findInput.addEventListener('input', function() { doSearch(findInput.value); });
        findInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                if (e.shiftKey) { navigateMatch(-1); } else { navigateMatch(1); }
            }
            if (e.key === 'Escape') { e.preventDefault(); closeFindBar(); }
        });

        findBar.querySelector('[data-dir="prev"]').addEventListener('click', function() { navigateMatch(-1); });
        findBar.querySelector('[data-dir="next"]').addEventListener('click', function() { navigateMatch(1); });
        findBar.querySelector('[data-dir="close"]').addEventListener('click', function() { closeFindBar(); });
    }

    function openFindBar() {
        if (!findBar) createFindBar();
        findBar.style.display = 'flex';
        findInput.focus();
        findInput.select();
    }

    function closeFindBar() {
        if (!findBar) return;
        findBar.style.display = 'none';
        clearHighlights();
        findInput.value = '';
        countDisplay.textContent = '';
    }

    function isFindOpen() {
        return findBar && findBar.style.display === 'flex';
    }

    function clearHighlights() {
        var marks = document.querySelectorAll('mark.marka-highlight');
        marks.forEach(function(mark) {
            var parent = mark.parentNode;
            parent.replaceChild(document.createTextNode(mark.textContent), mark);
            parent.normalize();
        });
        matches = [];
        currentMatch = -1;
    }

    function doSearch(query) {
        clearHighlights();
        if (!query) { countDisplay.textContent = ''; return; }

        var content = document.getElementById('content');
        highlightInNode(content, query.toLowerCase());
        matches = Array.from(document.querySelectorAll('mark.marka-highlight'));

        if (matches.length > 0) {
            currentMatch = 0;
            matches[0].classList.add('active');
            matches[0].scrollIntoView({ block: 'center', behavior: 'smooth' });
            countDisplay.textContent = '1 of ' + matches.length;
        } else {
            countDisplay.textContent = 'No matches';
        }
    }

    function highlightInNode(node, query) {
        if (node.nodeType === 3) {
            var text = node.textContent;
            var lower = text.toLowerCase();
            var idx = lower.indexOf(query);
            if (idx === -1) return;

            var frag = document.createDocumentFragment();
            var lastIdx = 0;
            while (idx !== -1) {
                frag.appendChild(document.createTextNode(text.substring(lastIdx, idx)));
                var mark = document.createElement('mark');
                mark.className = 'marka-highlight';
                mark.textContent = text.substring(idx, idx + query.length);
                frag.appendChild(mark);
                lastIdx = idx + query.length;
                idx = lower.indexOf(query, lastIdx);
            }
            frag.appendChild(document.createTextNode(text.substring(lastIdx)));
            node.parentNode.replaceChild(frag, node);
        } else if (node.nodeType === 1 && node.tagName !== 'MARK' && node.tagName !== 'SCRIPT' && node.tagName !== 'STYLE') {
            var children = Array.from(node.childNodes);
            children.forEach(function(child) { highlightInNode(child, query); });
        }
    }

    function navigateMatch(dir) {
        if (matches.length === 0) return;
        matches[currentMatch].classList.remove('active');
        currentMatch = (currentMatch + dir + matches.length) % matches.length;
        matches[currentMatch].classList.add('active');
        matches[currentMatch].scrollIntoView({ block: 'center', behavior: 'smooth' });
        countDisplay.textContent = (currentMatch + 1) + ' of ' + matches.length;
    }

    document.addEventListener('keydown', function(e) {
        if (e.metaKey && e.key === 'f') {
            e.preventDefault();
            openFindBar();
        }
        if (e.key === 'Escape' && isFindOpen()) {
            e.preventDefault();
            closeFindBar();
        }
    });

    // Expose for Swift-side menu item trigger
    window.markaOpenFind = openFindBar;
    window.markaCloseFindBar = closeFindBar;
    window.markaIsFindOpen = isFindOpen;
})();

// --- Keyboard navigation ---

(function() {
    var lastKey = '';
    var lastKeyTime = 0;
    var helpVisible = false;

    function createHelpOverlay() {
        var overlay = document.createElement('div');
        overlay.id = 'marka-help';
        overlay.innerHTML = `
            <div class="marka-help-inner">
                <h3>Keyboard Shortcuts</h3>
                <table>
                    <tr><td><kbd>j</kbd> / <kbd>k</kbd></td><td>Scroll down / up</td></tr>
                    <tr><td><kbd>J</kbd> / <kbd>K</kbd></td><td>Scroll down / up (fast)</td></tr>
                    <tr><td><kbd>g g</kbd></td><td>Jump to top</td></tr>
                    <tr><td><kbd>G</kbd></td><td>Jump to bottom</td></tr>
                    <tr><td><kbd>u</kbd> / <kbd>d</kbd></td><td>Half-page up / down</td></tr>
                    <tr><td><kbd>\u{2318}F</kbd></td><td>Find in page</td></tr>
                    <tr><td><kbd>?</kbd></td><td>Toggle this help</td></tr>
                    <tr><td><kbd>Esc</kbd></td><td>Close help / find</td></tr>
                </table>
            </div>
        `;
        document.body.appendChild(overlay);
        return overlay;
    }

    function toggleHelp() {
        var overlay = document.getElementById('marka-help');
        if (!overlay) overlay = createHelpOverlay();
        helpVisible = !helpVisible;
        overlay.style.display = helpVisible ? 'flex' : 'none';
    }

    document.addEventListener('keydown', function(e) {
        if (e.metaKey || e.ctrlKey || e.altKey) return;
        if (window.markaIsFindOpen && window.markaIsFindOpen()) return;

        var key = e.key;
        var now = Date.now();

        if (key === '?' || (key === '/' && e.shiftKey)) {
            e.preventDefault();
            toggleHelp();
            return;
        }

        if (key === 'Escape') {
            if (helpVisible) { toggleHelp(); e.preventDefault(); }
            return;
        }

        if (helpVisible) return;

        var halfPage = window.innerHeight / 2;

        switch (key) {
            case 'j': window.scrollBy({ top: 80, behavior: 'smooth' }); e.preventDefault(); break;
            case 'k': window.scrollBy({ top: -80, behavior: 'smooth' }); e.preventDefault(); break;
            case 'J': window.scrollBy({ top: 400, behavior: 'smooth' }); e.preventDefault(); break;
            case 'K': window.scrollBy({ top: -400, behavior: 'smooth' }); e.preventDefault(); break;
            case 'd': window.scrollBy({ top: halfPage, behavior: 'smooth' }); e.preventDefault(); break;
            case 'u': window.scrollBy({ top: -halfPage, behavior: 'smooth' }); e.preventDefault(); break;
            case 'G':
                window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
                e.preventDefault();
                break;
            case 'g':
                if (lastKey === 'g' && (now - lastKeyTime) < 500) {
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                    e.preventDefault();
                    lastKey = '';
                    return;
                }
                break;
        }
        lastKey = key;
        lastKeyTime = now;
    });
})();
</script>
"""#
}
