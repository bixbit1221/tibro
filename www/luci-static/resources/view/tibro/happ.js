'use strict';
'require view';

return view.extend({
    render: function() {
        var container = document.createElement('div');
        if (!document.querySelector('meta[name=viewport]')) {
            var vp = document.createElement('meta');
            vp.name = 'viewport';
            vp.content = 'width=device-width, initial-scale=1.0';
            document.head.appendChild(vp);
        }
        container.innerHTML = `
        <style>
        .tibro-wrap { font-family:sans-serif; padding:10px; }
        .tibro-card { background:#1a1a2e; border-radius:8px; padding:15px; margin:10px 0; color:#eee; }
        .tibro-btn { padding:6px 14px; border:none; border-radius:4px; cursor:pointer; font-size:12px; }
        .btn-connect { background:#27ae60; color:#fff; }
        .btn-refresh { background:#2980b9; color:#fff; margin-right:8px; }
        .btn-connecting { background:#f39c12; color:#fff; }
        .btn-ping-all { background:#8e44ad; color:#fff; }
        table { width:100%; border-collapse:collapse; margin-top:8px; }
        th { background:#2c3e50; padding:7px; text-align:left; font-size:12px; color:#eee; }
        td { padding:6px 7px; font-size:12px; border-bottom:1px solid #222; color:#ddd; }
        tr:nth-child(even) td { background:#111; }
        tr:nth-child(odd) td { background:#1a1a1a; }
        .active-row td { background:#0d2b0d!important; color:#7fff7f!important; }
        .badge { padding:2px 7px; border-radius:3px; font-size:11px; }
        .badge-xhttp { background:#1a4a2e; color:#7fff7f; }
        .badge-grpc  { background:#1a2a4a; color:#7faeff; }
        .badge-ws    { background:#3a2a1a; color:#ffbf7f; }
        .badge-tcp   { background:#2a2a2a; color:#aaa; }
        .badge-hysteria { background:#4a1a4a; color:#ff7fff; }
        .ping-good { color:#27ae60; font-size:11px; }
        .ping-bad  { color:#c0392b; font-size:11px; }
        .ping-wait { color:#888; font-size:11px; }
        .btn-ping-one { background:none; border:none; cursor:pointer; font-size:13px; padding:0 3px; opacity:0.6; }
        .btn-ping-one:hover { opacity:1; }
@media (max-width: 600px) {
  table, thead, tbody, th, td, tr { display:block; }
  thead tr { position:absolute; top:-9999px; left:-9999px; }
  tr { margin-bottom:10px; border:1px solid #333; border-radius:6px; padding:6px; }
  td { border:none; padding:5px 0; position:relative; padding-left:45%; text-align:left; }
  td:before { position:absolute; left:6px; width:40%; white-space:nowrap; font-weight:bold; color:#888; content:attr(data-label); }
}
        </style>
        <div class="tibro-wrap">
          <h2>&#128268; <span id="page-label-happ">Happ</span> <button class="btn-ping-one" onclick="editLabelHapp()" title="Переименовать">&#9998;</button></h2>
          <div class="tibro-card">
          <div class="tibro-card">
            <label style="display:block;margin-bottom:6px;color:#aaa;font-size:12px;">URL подписки:</label>
            <input type="text" id="sub-url-happ" style="width:100%;box-sizing:border-box;padding:8px;border-radius:4px;border:1px solid #333;background:#0d0d1a;color:#eee;font-size:12px;margin-bottom:8px;">
            <button class="tibro-btn btn-connect" onclick="saveSubHapp()">&#128190; Сохранить и обновить</button>
            <span id="sub-status-happ" style="margin-left:10px;font-size:12px;color:#888;"></span>
          </div>
            <button class="tibro-btn btn-refresh" onclick="loadNodesHapp()">&#8635; Обновить</button>
            <button class="tibro-btn btn-ping-all" onclick="pingNodes()">&#9889; Все пинги</button>
            <div id="nodes-container-happ" style="margin-top:10px"><p style="color:#888">Загрузка...</p></div>
          </div>
        </div>`;

        var PROVIDER = 'happ';
        var activeProvider = '';
        var activeIdx = -1;
        var pendingIdx = -1;
        var allNodes = [];
        var pingCache = {};

        function getApi(params) {
            var url = window.location.protocol + '//' + window.location.host + '/cgi-bin/tibro-api';
            if (params) url += '?' + params;
            return fetch(url, {credentials: 'include'}).then(function(r) { return r.json(); });
        }

        function pingOne(i, host, port) {
            var el = document.getElementById('ping-happ-' + i);
            if (el) el.innerHTML = '<span class="ping-wait">&#8987;</span> <button class="btn-ping-one" onclick="pingSingleHapp(' + i + ')">&#9889;</button>';
            getApi('action=ping&host=' + host + '&port=' + port)
            .then(function(d) {
                pingCache[i] = d.ms || 9999;
                if (el) el.innerHTML = (pingCache[i] < 1000
                    ? '<span class="ping-good">&#9679; ' + pingCache[i] + ' ms</span>'
                    : '<span class="ping-bad">&#9679; ' + pingCache[i] + ' ms</span>') +
                    ' <button class="btn-ping-one" onclick="pingSingleHapp(' + i + ')">&#9889;</button>';
            }).catch(function() {
                pingCache[i] = 9999;
                if (el) el.innerHTML = '<span class="ping-bad">&#9679; err</span> <button class="btn-ping-one" onclick="pingSingleHapp(' + i + ')">&#9889;</button>';
            });
        }

        function renderNodes() {
            var html = '<table><tr><th>#</th><th>Название</th><th>Хост</th><th>Тип</th><th>Пинг</th><th>Действие</th></tr>';
            allNodes.forEach(function(n, i) {
                var isActive = activeProvider === PROVIDER && i === activeIdx;
                var isPending = i === pendingIdx;
                var rowClass = isActive ? ' class="active-row"' : '';
                var pingBtn = '<button class="btn-ping-one" onclick="pingSingleHapp(' + i + ')">&#9889;</button>';
                var ping = pingCache[i] !== undefined
                    ? (pingCache[i] < 1000
                        ? '<span class="ping-good">&#9679; ' + pingCache[i] + ' ms</span>'
                        : '<span class="ping-bad">&#9679; ' + pingCache[i] + ' ms</span>')
                    : '<span class="ping-wait">—</span>';
                var badgeClass = 'badge badge-' + (n.transport || 'tcp');
                var btn = isActive
                    ? '<span style="color:#7fff7f">&#9679; Активна</span>'
                    : isPending
                        ? '<button class="tibro-btn btn-connecting" disabled>&#8635;...</button>'
                        : '<button class="tibro-btn btn-connect" onclick="switchNodeHapp(' + i + ')">&#9654; Подключить</button>';
                html += '<tr' + rowClass + '>' +
                    '<td data-label="#">' + i + '</td>' +
                    '<td data-label="Название">' + (n.name||'—') + '</td>' +
                    '<td data-label="Хост" style="font-size:10px">' + (n.host||'—') + ':' + (n.port||'') + '</td>' +
                    '<td data-label="Тип"><span class="' + badgeClass + '">' + (n.transport||'tcp') + '</span></td>' +
                    '<td data-label="Пинг" id="ping-happ-' + i + '">' + ping + ' ' + pingBtn + '</td>' +
                    '<td data-label="Действие">' + btn + '</td></tr>';
            });
            html += '</table>';
            var el = document.getElementById('nodes-container-happ');
            if (el) el.innerHTML = html;
        }

        window.pingNodes = function() {
            allNodes.forEach(function(n, i) {
                pingOne(i, n.host, n.port);
            });
        };

        window.pingSingleHapp = function(i) {
            var n = allNodes[i];
            if (n) pingOne(i, n.host, n.port);
        };

        window.loadNodesHapp = function() {
            getApi('').then(function(s) {
                activeProvider = s.provider;
                activeIdx = parseInt(s.node_idx);
                var inp = document.getElementById('sub-url-happ');
                if (inp && !inp.dataset.touched) inp.value = s.sub_happ || '';
                var lbl = document.getElementById('page-label-happ');
                if (lbl && s.label_happ) lbl.textContent = s.label_happ;
                return getApi('action=nodes&provider=' + PROVIDER);
            }).then(function(nodes) {
                allNodes = nodes;
                renderNodes();
                pingNodes();
            }).catch(function() {
                var el = document.getElementById('nodes-container-happ');
                if (el) el.innerHTML = '<p style="color:#c0392b">Ошибка</p>';
            });
        };

        window.saveSubHapp = function() {
            var inp = document.getElementById('sub-url-happ');
            var st = document.getElementById('sub-status-happ');
            if (!inp || !inp.value.trim()) return;
            if (st) st.textContent = 'Сохранение...';
            getApi('action=setsub&provider=happ&url=' + encodeURIComponent(inp.value.trim()))
            .then(function(d) {
                if (st) st.textContent = d.ok ? 'Сохранено, обновляю ноды...' : 'Ошибка сохранения';
                setTimeout(function() {
                    loadNodesHapp();
                    if (st) st.textContent = 'Готово';
                    setTimeout(function() { if (st) st.textContent = ''; }, 3000);
                }, 3000);
            }).catch(function() {
                if (st) st.textContent = 'Ошибка запроса';
            });
        };

        window.editLabelHapp = function() {
            var span = document.getElementById('page-label-happ');
            if (!span) return;
            var current = span.textContent;
            var newLabel = prompt('Новое название:', current);
            if (newLabel === null || !newLabel.trim() || newLabel.trim() === current) return;
            getApi('action=setlabel&provider=happ&label=' + encodeURIComponent(newLabel.trim()))
            .then(function(d) {
                if (d.ok) span.textContent = newLabel.trim();
            });
        };

        window.switchNodeHapp = function(idx) {
            pendingIdx = idx;
            renderNodes();
            getApi('action=switch&provider=' + PROVIDER + '&node=' + idx)
            .then(function(d) {
                if (!d.ok) { pendingIdx = -1; renderNodes(); return; }
                var attempts = 0;
                var poll = setInterval(function() {
                    attempts++;
                    getApi('').then(function(s) {
                        if ((s.provider === PROVIDER && parseInt(s.node_idx) === idx) || attempts > 15) {
                            clearInterval(poll);
                            activeProvider = s.provider;
                            activeIdx = parseInt(s.node_idx);
                            pendingIdx = -1;
                            renderNodes();
                        }
                    });
                }, 1000);
            });
        };

        setTimeout(loadNodesHapp, 300);
        setTimeout(function() {
            var inp = document.getElementById('sub-url-happ');
            if (inp) inp.addEventListener('input', function() { inp.dataset.touched = '1'; });
        }, 500);
        return container;
    },

    handleSave: null,
    handleSaveApply: null,
    handleReset: null
});
