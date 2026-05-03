const storageKey = "treescape.admin.apiBaseUrl";

const state = {
  apiBaseUrl: localStorage.getItem(storageKey) || "http://localhost:8080",
  secret: "",
  overview: null,
  selectedUserId: "",
  detail: null,
  search: "",
  loadingOverview: false,
  loadingDetail: false,
  status: null,
};

const elements = {};

document.addEventListener("DOMContentLoaded", () => {
  cacheElements();
  bindEvents();
  elements.apiBaseUrlInput.value = state.apiBaseUrl;
  render();
});

function cacheElements() {
  elements.connectForm = document.getElementById("connectForm");
  elements.apiBaseUrlInput = document.getElementById("apiBaseUrlInput");
  elements.adminSecretInput = document.getElementById("adminSecretInput");
  elements.connectButton = document.getElementById("connectButton");
  elements.refreshButton = document.getElementById("refreshButton");
  elements.lockButton = document.getElementById("lockButton");
  elements.statusBanner = document.getElementById("statusBanner");
  elements.metricsGrid = document.getElementById("metricsGrid");
  elements.usersList = document.getElementById("usersList");
  elements.detailPanel = document.getElementById("detailPanel");
  elements.userSearchInput = document.getElementById("userSearchInput");
}

function bindEvents() {
  elements.connectForm.addEventListener("submit", handleConnect);
  elements.refreshButton.addEventListener("click", () => {
    if (!state.secret) {
      setStatus("Enter the admin secret before refreshing.", "error");
      render();
      return;
    }
    refreshDashboard({ preserveSelection: true });
  });
  elements.lockButton.addEventListener("click", lockDashboard);
  elements.userSearchInput.addEventListener("input", (event) => {
    state.search = event.target.value.trim().toLowerCase();
    renderUsers();
  });
}

async function handleConnect(event) {
  event.preventDefault();
  state.apiBaseUrl = normalizeBaseUrl(elements.apiBaseUrlInput.value);
  state.secret = elements.adminSecretInput.value.trim();

  if (!state.apiBaseUrl || !state.secret) {
    setStatus("Both the API base URL and admin secret are required.", "error");
    render();
    return;
  }

  localStorage.setItem(storageKey, state.apiBaseUrl);
  await refreshDashboard({ preserveSelection: false });
}

async function refreshDashboard({ preserveSelection }) {
  state.loadingOverview = true;
  if (!preserveSelection) {
    state.selectedUserId = "";
    state.detail = null;
  }
  setStatus("Loading admin overview…", "success");
  render();

  try {
    const data = await apiRequest("/v1/admin/overview");
    state.overview = data.overview;

    const availableUsers = state.overview.users || [];
    const selectedStillExists = availableUsers.some(
      (user) => user.user.id === state.selectedUserId,
    );
    if (!state.selectedUserId || !selectedStillExists) {
      state.selectedUserId = availableUsers[0]?.user.id || "";
    }

    state.loadingOverview = false;
    setStatus("Connected.", "success");
    render();

    if (state.selectedUserId) {
      await loadUserDetail(state.selectedUserId);
    }
  } catch (error) {
    state.loadingOverview = false;
    state.overview = null;
    state.detail = null;
    state.selectedUserId = "";
    setStatus(error.message, "error");
    render();
  }
}

async function loadUserDetail(userId) {
  if (!userId) {
    state.detail = null;
    renderDetail();
    return;
  }

  state.selectedUserId = userId;
  state.loadingDetail = true;
  renderUsers();
  renderDetail();

  try {
    const data = await apiRequest(`/v1/admin/users/${userId}`);
    state.detail = data.user;
    state.loadingDetail = false;
    renderDetail();
    renderUsers();
  } catch (error) {
    state.loadingDetail = false;
    state.detail = null;
    setStatus(error.message, "error");
    renderDetail();
    renderUsers();
  }
}

function lockDashboard() {
  state.secret = "";
  state.overview = null;
  state.detail = null;
  state.selectedUserId = "";
  state.loadingOverview = false;
  state.loadingDetail = false;
  elements.adminSecretInput.value = "";
  setStatus("Admin session cleared.", "success");
  render();
}

async function handleGrantInventory(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const itemKey = form.elements.itemKey.value.trim();
  const quantity = Number(form.elements.quantity.value);

  await adminMutation(
    `/v1/admin/users/${state.selectedUserId}/inventory`,
    {
      method: "POST",
      body: JSON.stringify({ item_key: itemKey, quantity }),
    },
    "Inventory granted.",
  );
}

async function handleGrantXP(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const skillKey = form.elements.skillKey.value.trim();
  const xp = Number(form.elements.xp.value);

  await adminMutation(
    `/v1/admin/users/${state.selectedUserId}/skills/xp`,
    {
      method: "POST",
      body: JSON.stringify({ skill_key: skillKey, xp }),
    },
    "XP granted.",
  );
}

async function handleTeleport(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const x = Number(form.elements.x.value);
  const y = Number(form.elements.y.value);

  await adminMutation(
    `/v1/admin/users/${state.selectedUserId}/position`,
    {
      method: "POST",
      body: JSON.stringify({ x, y }),
    },
    "Player moved.",
  );
}

async function adminMutation(path, options, successMessage) {
  if (!state.selectedUserId) {
    return;
  }

  try {
    setStatus("Applying admin action…", "success");
    render();
    await apiRequest(path, options);
    setStatus(successMessage, "success");
    await refreshDashboard({ preserveSelection: true });
  } catch (error) {
    setStatus(error.message, "error");
    render();
  }
}

async function apiRequest(path, options = {}) {
  if (!state.secret) {
    throw new Error("Admin secret is missing.");
  }

  const response = await fetch(toApiUrl(path), {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
      "X-Admin-Secret": state.secret,
      ...(options.headers || {}),
    },
    ...options,
  });

  let payload = null;
  try {
    payload = await response.json();
  } catch (_) {
    payload = null;
  }

  if (!response.ok) {
    const message =
      payload?.error?.message ||
      `Request failed with status ${response.status}.`;
    throw new Error(message);
  }

  return payload?.data || {};
}

function toApiUrl(path) {
  return new URL(path, `${state.apiBaseUrl}/`).toString();
}

function normalizeBaseUrl(value) {
  return value.trim().replace(/\/+$/, "");
}

function setStatus(message, tone) {
  state.status = { message, tone };
}

function render() {
  renderStatus();
  renderMetrics();
  renderUsers();
  renderDetail();
  elements.connectButton.disabled = state.loadingOverview;
  elements.refreshButton.disabled = !state.secret || state.loadingOverview;
  elements.lockButton.disabled = !state.secret;
}

function renderStatus() {
  if (!state.status?.message) {
    elements.statusBanner.className = "status-banner hidden";
    elements.statusBanner.textContent = "";
    return;
  }

  elements.statusBanner.className = `status-banner ${state.status.tone || "success"}`;
  elements.statusBanner.textContent = state.status.message;
}

function renderMetrics() {
  if (!state.overview) {
    elements.metricsGrid.innerHTML = "";
    return;
  }

  const totals = state.overview.totals;
  const metrics = [
    ["Total Users", totals.total_users],
    ["Guest Users", totals.guest_users],
    ["Local Users", totals.local_users],
    ["Active Players", totals.active_players],
    ["Moving Players", totals.moving_players],
  ];

  elements.metricsGrid.innerHTML = metrics
    .map(
      ([label, value]) => `
        <article class="card metric-card">
          <h3>${escapeHtml(label)}</h3>
          <strong>${escapeHtml(String(value ?? 0))}</strong>
        </article>
      `,
    )
    .join("");
}

function renderUsers() {
  if (!state.overview) {
    elements.usersList.className = "users-list empty-state";
    elements.usersList.textContent =
      state.loadingOverview ? "Loading users…" : "Connect to load users.";
    return;
  }

  const users = filteredUsers();
  if (users.length === 0) {
    elements.usersList.className = "users-list empty-state";
    elements.usersList.textContent = "No users match the current filter.";
    return;
  }

  elements.usersList.className = "users-list";
  elements.usersList.innerHTML = users
    .map((entry) => {
      const active = entry.user.id === state.selectedUserId ? "active" : "";
      return `
        <button class="user-row ${active}" data-user-id="${escapeHtml(entry.user.id)}" type="button">
          <div>
            <h3>${escapeHtml(entry.user.display_name)}</h3>
            <p>
              ${escapeHtml(entry.user.provider)}
              ${entry.user.username ? ` · ${escapeHtml(entry.user.username)}` : ""}
              · ${escapeHtml(entry.status)}
            </p>
            <p>Pos ${escapeHtml(String(entry.player_x))}, ${escapeHtml(String(entry.player_y))}</p>
          </div>
          <div class="user-stat">
            <strong>WC ${escapeHtml(String(entry.woodcutting_level))}</strong>
            <span>${escapeHtml(String(entry.woodcutting_xp))} XP</span>
          </div>
        </button>
      `;
    })
    .join("");

  for (const button of elements.usersList.querySelectorAll(".user-row")) {
    button.addEventListener("click", () => {
      const userId = button.dataset.userId;
      if (userId) {
        loadUserDetail(userId);
      }
    });
  }
}

function renderDetail() {
  if (state.loadingDetail) {
    elements.detailPanel.className = "detail-panel empty-state";
    elements.detailPanel.textContent = "Loading player detail…";
    return;
  }

  if (!state.detail) {
    elements.detailPanel.className = "detail-panel empty-state";
    elements.detailPanel.textContent = state.overview
      ? "Select a player to inspect and manage them."
      : "Connect to load player detail.";
    return;
  }

  const detail = state.detail;
  const player = detail.player;
  const items = detail.items || [];
  const skills = detail.skills || [];
  const world = detail.world || {};
  const action = detail.action;

  elements.detailPanel.className = "detail-panel";
  elements.detailPanel.innerHTML = `
    <div class="detail-header">
      <div class="detail-title">
        <p class="eyebrow">Selected Player</p>
        <h2>${escapeHtml(detail.user.display_name)}</h2>
        <p>
          ${escapeHtml(detail.user.provider)}
          ${detail.user.username ? ` · ${escapeHtml(detail.user.username)}` : ""}
          · ${escapeHtml(detail.user.id)}
        </p>
      </div>
      <button id="detailRefreshButton" class="pill-button" type="button">Reload Player</button>
    </div>

    <div class="meta-grid">
      <div class="meta-card">
        <span class="meta-label">Position</span>
        <strong class="meta-value">${escapeHtml(String(player.x))}, ${escapeHtml(String(player.y))}</strong>
      </div>
      <div class="meta-card">
        <span class="meta-label">Action</span>
        <strong class="meta-value">${escapeHtml(action ? action.type : "idle")}</strong>
      </div>
      <div class="meta-card">
        <span class="meta-label">Created</span>
        <strong class="meta-value">${escapeHtml(formatDate(detail.user.created_at))}</strong>
      </div>
      <div class="meta-card">
        <span class="meta-label">Updated</span>
        <strong class="meta-value">${escapeHtml(formatDate(player.updated_at))}</strong>
      </div>
    </div>

    <div class="action-grid">
      <section class="detail-card-block">
        <p class="eyebrow">Inventory</p>
        <h3>Grant Item</h3>
        <form id="grantInventoryForm" class="action-form">
          <label>
            <span>Item Key</span>
            <input name="itemKey" value="logs" required />
          </label>
          <label>
            <span>Quantity</span>
            <input name="quantity" type="number" min="1" step="1" value="100" required />
          </label>
          <button class="primary-button" type="submit">Grant Item</button>
        </form>
      </section>

      <section class="detail-card-block">
        <p class="eyebrow">Skills</p>
        <h3>Grant XP</h3>
        <form id="grantXPForm" class="action-form">
          <label>
            <span>Skill Key</span>
            <input name="skillKey" value="woodcutting" required />
          </label>
          <label>
            <span>XP</span>
            <input name="xp" type="number" min="1" step="1" value="500" required />
          </label>
          <button class="primary-button" type="submit">Grant XP</button>
        </form>
      </section>

      <section class="detail-card-block">
        <p class="eyebrow">Movement</p>
        <h3>Teleport Player</h3>
        <form id="teleportForm" class="action-form">
          <label>
            <span>X</span>
            <input name="x" type="number" step="1" value="${escapeHtml(String(player.x))}" required />
          </label>
          <label>
            <span>Y</span>
            <input name="y" type="number" step="1" value="${escapeHtml(String(player.y))}" required />
          </label>
          <button class="primary-button" type="submit">Move Player</button>
        </form>
      </section>
    </div>

    <div class="summary-grid">
      <div class="summary-card">
        <span class="meta-label">Inventory Slots</span>
        <strong>${escapeHtml(String(items.length))}</strong>
      </div>
      <div class="summary-card">
        <span class="meta-label">Skills</span>
        <strong>${escapeHtml(String(skills.length))}</strong>
      </div>
      <div class="summary-card">
        <span class="meta-label">Entities</span>
        <strong>${escapeHtml(String(world.total_entities || 0))}</strong>
      </div>
    </div>

    <div class="detail-grid">
      <section class="detail-card-block">
        <p class="eyebrow">Inventory</p>
        <h3>Items</h3>
        ${renderKeyValueRows(items, "item_key", "quantity")}
      </section>
      <section class="detail-card-block">
        <p class="eyebrow">Progression</p>
        <h3>Skills</h3>
        ${renderSkillRows(skills)}
      </section>
      <section class="detail-card-block">
        <p class="eyebrow">World</p>
        <h3>Resources</h3>
        <div class="list-table">
          <div class="list-row">
            <strong>Active Resources</strong>
            <span>${escapeHtml(String(world.active_resources || 0))}</span>
          </div>
          <div class="list-row">
            <strong>Depleted Resources</strong>
            <span>${escapeHtml(String(world.depleted_resources || 0))}</span>
          </div>
        </div>
        <div class="resource-chip-wrap">
          ${renderResourceChips(world.resource_counts || {})}
        </div>
      </section>
    </div>
  `;

  document
    .getElementById("detailRefreshButton")
    .addEventListener("click", () => loadUserDetail(state.selectedUserId));
  document
    .getElementById("grantInventoryForm")
    .addEventListener("submit", handleGrantInventory);
  document.getElementById("grantXPForm").addEventListener("submit", handleGrantXP);
  document.getElementById("teleportForm").addEventListener("submit", handleTeleport);
}

function filteredUsers() {
  const users = state.overview?.users || [];
  if (!state.search) {
    return users;
  }
  return users.filter((entry) => {
    const haystack = [
      entry.user.display_name,
      entry.user.username || "",
      entry.user.provider,
      entry.status,
    ]
      .join(" ")
      .toLowerCase();
    return haystack.includes(state.search);
  });
}

function renderKeyValueRows(items, keyField, valueField) {
  if (!items.length) {
    return '<div class="empty-state">No records.</div>';
  }

  return `
    <div class="list-table">
      ${items
        .map(
          (item) => `
            <div class="list-row">
              <strong>${escapeHtml(String(item[keyField]))}</strong>
              <span>${escapeHtml(String(item[valueField]))}</span>
            </div>
          `,
        )
        .join("")}
    </div>
  `;
}

function renderSkillRows(skills) {
  if (!skills.length) {
    return '<div class="empty-state">No skills yet.</div>';
  }

  return `
    <div class="list-table">
      ${skills
        .map(
          (skill) => `
            <div class="list-row">
              <strong>${escapeHtml(skill.skill_key)}</strong>
              <span>Level ${escapeHtml(String(skill.level))} · ${escapeHtml(String(skill.xp))} XP</span>
            </div>
          `,
        )
        .join("")}
    </div>
  `;
}

function renderResourceChips(resourceCounts) {
  const entries = Object.entries(resourceCounts);
  if (!entries.length) {
    return '<span class="resource-chip">No resource data</span>';
  }
  return entries
    .map(
      ([key, value]) =>
        `<span class="resource-chip">${escapeHtml(key)} · ${escapeHtml(String(value))}</span>`,
    )
    .join("");
}

function formatDate(value) {
  if (!value) {
    return "n/a";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "n/a";
  }
  return `${date.toLocaleDateString()} ${date.toLocaleTimeString()}`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
