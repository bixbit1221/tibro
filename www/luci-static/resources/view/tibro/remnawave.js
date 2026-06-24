'use strict';
'require view';

return view.extend({
    render: function() {
        var container = document.createElement('div');
        container.innerHTML = `
        <style>
        .tibro-wrap { font-family:sans-serif; padding:10px; }
        .tibro-card { background:#1a1a2e; border-radius:8px; padding:15px; margin:10px 0; color:#eee; }
        .tibro-btn { padding:6px 14px; border:none; border-radius:4px; cursor:pointer; font-size:12px; }
        .btn-connect { background:#27ae60; color:#fff; }
        .btn-refresh { background:#2980b9; color:#fff; margin-bottom:10px; }
        table { width:100%; border-collapse:collapse; margin-top:8px; }
        th { background:#2c3e50; padding:7px; text-align:left; font-size:12px; color:#eee; }
        td { padding:6px 7px; font-size:12px; border-bottom:1px solid #222; color:#ddd; }
        tr:nth-child(even) td { background:#111; }
        .active-row td { background:#0d2b0d!important; color:#7fff7f!important; }
        .badge { background:#2c3e50; padding:2px 7px; border-radius:3px; font-size:11px; color:#aef; }
        </style>
        <div class="tibro-wrap">
          <h2>&#128268; Remnawave</h2>
          <div class="tibro-card">
            <button class="tibro-btn btn-refresh" onclick="loadNodes()">&#8635; Обновить</button>
            <div id="nodes-container"><p style="color:#888">Загрузка...</p></div>
          </div>
        </div>`;

        window.loadNodes = function() {
            var activeProvider = '', activeIdx = -1;
            fetch('/cgi-bin/tibro-api')
                .then(r => r.json())
                .then(s => {
                    activeProvider = s.provider;
                    activeIdx = parseInt(s.node_idx);
                    return fetch('/cgi-bin/tibro-api?action=nodes&provider=remnawave');
                })
                .then(r => r.json())
                .then(nodes => {
                    if (!nodes.length) {
                        document.getElementById('nodes-container').innerHTML =
                            '<p style="color:#888">Нет нод. Обновите подписки.</p>';
                        return;
                    }
                    var html = '<table><tr><th>#</th><th>Название</th><th>Хост</th><th>Транспорт</th><th>Действие</th></tr>';
                    nodes.forEach(function(n, i) {
                        var isActive = activeProvider === 'remnawave' && i === activeIdx;
                        var rowClass = isActive ? ' class="active-row"' : '';
                        var btn = isActive
                            ? '<span style="color:#7fff7f">&#9679; Активна</span>'
                            : '<button class="tibro-btn btn-connect" onclick="switchNode(\'remnawave\',' + i + ')">&#9654; Подключить</button>';
                        html += '<tr' + rowClass + '><td>' + i + '</td><td>' + (n.name||'—') +
                            '</td><td style="font-size:11px">' + (n.host||'—') + ':' + (n.port||'') +
                            '</td><td><span class="badge">' + (n.transport||'tcp') + '</span></td>' +
                            '<td>' + btn + '</td></tr>';
                    });
                    html += '</table>';
                    document.getElementById('nodes-container').innerHTML = html;
                }).catch(() => {
                    document.getElementById('nodes-container').innerHTML =
                        '<p style="color:#c0392b">Ошибка загрузки</p>';
                });
        };

        window.switchNode = function(provider, idx) {
            fetch('/cgi-bin/tibro-api?action=switch&provider=' + provider + '&node=' + idx)
                .then(r => r.json())
                .then(d => { if (d.ok) setTimeout(loadNodes, 2500); });
        };

        setTimeout(loadNodes, 300);
        return container;
    },

    handleSave: null,
    handleSaveApply: null,
    handleReset: null
});
