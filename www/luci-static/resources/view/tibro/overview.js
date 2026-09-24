'use strict';
'require view';
'require poll';

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
        .tibro-status { font-size:18px; font-weight:bold; }
        .tibro-btn { padding:8px 18px; border:none; border-radius:4px; cursor:pointer; font-size:13px; margin:4px; }
        .btn-stop { background:#c0392b; color:#fff; }
        .btn-update { background:#2980b9; color:#fff; }
        .tibro-log { background:#000; border-radius:4px; padding:8px; font-family:monospace;
                     font-size:11px; color:#0f0; white-space:pre-wrap; max-height:200px; overflow-y:auto; margin-top:10px; }
        </style>
        <div class="tibro-wrap">
          <h2>&#128268; Tibro VPN</h2>
          <div class="tibro-card">
            <div class="tibro-status" id="t-status">...</div>
            <div id="t-node" style="color:#aaa;font-size:13px;margin-top:4px;"></div>
            <div style="margin-top:10px;">
              <button class="tibro-btn btn-stop" id="btn-stop">&#9632; </button>
              <button class="tibro-btn btn-update" id="btn-update">&#8635; </button>
            </div>
          </div>
          <div class="tibro-card">
            <b>:</b>
            <div class="tibro-log" id="t-log"></div>
          </div>
        </div>`;

        function apiCall(params) {
            var url = window.location.protocol + '//' + window.location.host + '/cgi-bin/tibro-api';
            if (params) url += '?' + params;
            return fetch(url, {credentials: 'include'}).then(function(r) { return r.json(); });
        }

        function refresh() {
            apiCall('').then(function(d) {
                var s = document.getElementById('t-status');
                var n = document.getElementById('t-node');
                var l = document.getElementById('t-log');
                if (!s) return;
                s.style.color = d.running ? '#27ae60' : '#c0392b';
                s.textContent = d.running
                    ? '  (PID ' + d.pid + ')'
                    : ' ';
                n.textContent = ': ' + d.provider + ' | : ' + d.node_idx;
                if (l && d.log) {
                    l.textContent = d.log.replace(/\\n/g, '\n');
                    l.scrollTop = l.scrollHeight;
                }
            }).catch(function(e) {
                var s = document.getElementById('t-status');
                if (s) s.textContent = ': ' + e;
            });
        }

        container.querySelector('#btn-stop').addEventListener('click', function() {
            if (!confirm(' Tibro?')) return;
            apiCall('action=stop').then(function() { setTimeout(refresh, 1500); });
        });

        container.querySelector('#btn-update').addEventListener('click', function() {
            apiCall('action=update').then(function() { alert('  '); });
        });

        poll.add(refresh, 8);
        setTimeout(refresh, 300);

        return container;
    },

    handleSave: null,
    handleSaveApply: null,
    handleReset: null
});
