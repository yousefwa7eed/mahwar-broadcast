import { createClient } from '@supabase/supabase-js';
import './style.css';

const SB_URL = import.meta.env.VITE_SUPABASE_URL as string;
const SB_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

if (!SB_URL || !SB_KEY) {
  document.getElementById('app')!.innerHTML =
    '<div class="auth-wrap"><div class="auth-card">إعدادات البيئة ناقصة (VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY)</div></div>';
  throw new Error('missing env');
}

const sb = createClient(SB_URL, SB_KEY, {
  auth: { persistSession: true, autoRefreshToken: true },
});

// MFA is never skipped in production: the flag is read only in dev and must be
// opted into explicitly (VITE_SKIP_MFA=true). `import.meta.env.DEV` is
// statically false in `vite build`, so this condition folds to false.
const SKIP_MFA = import.meta.env.DEV && import.meta.env.VITE_SKIP_MFA === 'true';

const app = document.getElementById('app')!;

const appEl = () => document.createElement('div');
const fmt = (v: any) =>
  v == null ? '—' : new Date(v).toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' });
const esc = (v: any) => {
  const d = appEl();
  d.textContent = v == null ? '' : String(v);
  return d.innerHTML;
};

type SessionState = {
  user_id: string;
  is_admin_row: boolean;
  aal: string;
  mfa_enrolled: boolean;
};

async function rpcSilent<T = any>(name: string, args: Record<string, any> = {}): Promise<T> {
  const { data, error } = await (sb.rpc as any)(name, args);
  if (error) throw error;
  return data as T;
}

// ---------------------------------------------------------------------------
// Inline SVG icon set (stroke = currentColor).
// ---------------------------------------------------------------------------
const I = (d: string) =>
  `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}</svg>`;
const ICONS = {
  gauge: I('<path d="M3.5 17a9 9 0 1 1 17 0"/><path d="M12 13l3.5-2.5"/><circle cx="12" cy="13" r="1.2"/>'),
  users: I('<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>'),
  download: I('<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="3" x2="12" y2="15"/>'),
  logout: I('<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>'),
  search: I('<circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.5" y2="16.5"/>'),
  x: I('<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>'),
  chevronL: I('<polyline points="15 18 9 12 15 6"/>'),
  chevronR: I('<polyline points="9 18 15 12 9 6"/>'),
  car: I('<path d="M5 17h14M6.5 17a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm13 0a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Z"/><path d="M5 17l-1.3-4.3A2 2 0 0 1 5.6 10h12.8a2 2 0 0 1 1.9 2.7L19 17"/><path d="M7 10l1.2-3.4A2 2 0 0 1 10.1 5h3.8a2 2 0 0 1 1.9 1.6L17 10"/>'),
  bell: I('<path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>'),
  shield: I('<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/>'),
  star: I('<path d="M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.9L12 17.8 5.8 21l1.2-6.9-5-4.9 6.9-1L12 2Z"/>'),
  wrench: I('<path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4L15 12l-3-3 2.7-2.7Z"/>'),
  pin: I('<path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0Z"/><circle cx="12" cy="10" r="3"/>'),
  clipboard: I('<path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><rect x="8" y="2" width="8" height="4" rx="1"/>'),
  refresh: I('<polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>'),
  chart: I('<path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/>'),
};

// ---------------------------------------------------------------------------
// Boot: decide what screen to show based on session + admin state.
// ---------------------------------------------------------------------------
async function boot() {
  app.innerHTML = '<div class="auth-wrap"><div class="auth-card">جارٍ التحميل…</div></div>';

  try {
    const { data: sessData } = await sb.auth.getSession();
    const session = sessData?.session;

    if (!session) {
      showAuth();
      return;
    }

    let st: SessionState;
    try {
      st = await rpcSilent<SessionState>('admin_session_state');
    } catch (e: any) {
      await sb.auth.signOut();
      showAuth('انتهت صلاحية الجلسة، سجل الدخول من جديد');
      return;
    }

    if (!st.is_admin_row) {
      showUnauthorized();
      return;
    }

    if (SKIP_MFA) {
      showDashboard();
      return;
    }

    if (!st.mfa_enrolled) {
      await showEnroll();
      return;
    }

    const aal = st.aal;
    if (aal !== 'aal2') {
      await showAalVerify();
      return;
    }

    showDashboard();
  } catch (e: any) {
    showLoadError(e?.message ?? String(e), boot);
  }
}

// ---------------------------------------------------------------------------
// Auth screen: sign-in with existing account, or create the admin account
// (email-based; server trigger picks it up via signup_source=admin_dashboard).
// ---------------------------------------------------------------------------
function showAuth(message?: string) {
  app.innerHTML = '';
  const wrap = appEl();
  wrap.className = 'auth-wrap';
  wrap.innerHTML = `
    <div class="auth-card">
      <h1>برج مراقبة محور</h1>
      <div class="sub">لوحة الأدمن — دخول بالإيميل والتحقق بخطوة إضافية</div>
      <div class="msg info" id="msg"></div>
      <div class="auth-tabs">
        <button id="tab-login" class="active">تسجيل الدخول</button>
        <button id="tab-signup">إنشاء حساب أدمن</button>
      </div>

      <form id="login-form">
        <div class="field"><label>البريد الإلكتروني</label><input id="li-email" type="email" required dir="ltr" /></div>
        <div class="field"><label>كلمة السر</label><input id="li-pass" type="password" required dir="ltr" /></div>
        <button style="width:100%; margin-top:8px" type="submit">دخول</button>
      </form>

      <form id="signup-form" class="hidden">
        <div class="field"><label>البريد الإلكتروني</label><input id="su-email" type="email" required dir="ltr" /></div>
        <div class="field"><label>كلمة السر (12+ حرف)</label><input id="su-pass" type="password" required minlength="12" dir="ltr" /></div>
        <button style="width:100%; margin-top:8px" type="submit">إنشاء الحساب</button>
        <div class="sub" style="margin-top:10px">
          الحساب يُنشأ خارج التطبيق تمامًا. بعد إنشائه: فعّل البريد، سجل دخول،
          ثم سيُطلب منك ضبط التحقق بخطوة إضافية على جهازين قبل فتح اللوحة.
        </div>
      </form>
    </div>`;

  app.appendChild(wrap);

  const msg = wrap.querySelector('#msg') as HTMLDivElement;
  const setMsg = (text: string, kind: 'err' | 'info' | 'warn' = 'err') => {
    msg.textContent = text;
    msg.className = `msg ${kind} show`;
  };
  if (message) setMsg(message, 'warn');

  const tabLogin = wrap.querySelector('#tab-login') as HTMLButtonElement;
  const tabSignup = wrap.querySelector('#tab-signup') as HTMLButtonElement;
  const loginForm = wrap.querySelector('#login-form') as HTMLFormElement;
  const signupForm = wrap.querySelector('#signup-form') as HTMLFormElement;

  tabLogin.onclick = () => {
    tabLogin.classList.add('active');
    tabSignup.classList.remove('active');
    loginForm.classList.remove('hidden');
    signupForm.classList.add('hidden');
  };
  tabSignup.onclick = () => {
    tabSignup.classList.add('active');
    tabLogin.classList.remove('active');
    signupForm.classList.remove('hidden');
    loginForm.classList.add('hidden');
  };

  loginForm.onsubmit = async (ev) => {
    ev.preventDefault();
    const email = (wrap.querySelector('#li-email') as HTMLInputElement).value.trim();
    const password = (wrap.querySelector('#li-pass') as HTMLInputElement).value;
    const btn = loginForm.querySelector('button[type=submit]') as HTMLButtonElement;
    btn.disabled = true;
    const { error } = await sb.auth.signInWithPassword({ email, password });
    btn.disabled = false;
    if (error) return setMsg(error.message);
    boot();
  };

  signupForm.onsubmit = async (ev) => {
    ev.preventDefault();
    const email = (wrap.querySelector('#su-email') as HTMLInputElement).value.trim();
    const password = (wrap.querySelector('#su-pass') as HTMLInputElement).value;
    const btn = signupForm.querySelector('button[type=submit]') as HTMLButtonElement;
    btn.disabled = true;
    const { data, error } = await sb.auth.signUp({
      email,
      password,
      // Server trigger keys on this exact field: auth-only account, no app profile.
      options: { data: { signup_source: 'admin_dashboard' } },
    });
    btn.disabled = false;
    if (error) return setMsg(error.message);
    if (!data.session) {
      return setMsg('تم إنشاء الحساب. افتح بريدك وفعّل الحساب ثم سجل الدخول هنا.', 'info');
    }
    boot();
  };
}

// ---------------------------------------------------------------------------
// Unauthorized: signed in but NOT on the admins list.
// ---------------------------------------------------------------------------
function showUnauthorized() {
  app.innerHTML = '';
  const wrap = appEl();
  wrap.className = 'auth-wrap';
  wrap.innerHTML = `
    <div class="auth-card">
      <h1>غير مصرح</h1>
      <div class="sub">
        الحساب ده مش في قائمة الأدمن. الملّ أي أدمن لو أضيف معرّفه في جدول
        public.admins (خطوة SQL يدوية للمالك) ورجّع الدخول من هنا.
      </div>
      <button id="out">رجوع لتسجيل الدخول</button>
    </div>`;
  app.appendChild(wrap);
  (wrap.querySelector('#out') as HTMLButtonElement).onclick = async () => {
    await sb.auth.signOut();
    showAuth();
  };
}

// شاشة خطأ موحّدة لمسارات التحقق: تعرض السبب مع إعادة محاولة أو خروج،
// بدل التعليق على رسالة تحميل أو توجيه المستخدم للتفعيل عند خطأ قراءة.
function showLoadError(message: string, retry: () => void) {
  app.innerHTML = '';
  const wrap = appEl();
  wrap.className = 'auth-wrap';
  wrap.innerHTML = `
    <div class="auth-card">
      <h1>تعذّر إكمال التحقق</h1>
      <div class="msg err show">${esc(message)}</div>
      <button id="retry" style="width:100%">إعادة المحاولة</button>
      <button class="linklike" id="out">تسجيل الخروج</button>
    </div>`;
  app.appendChild(wrap);
  (wrap.querySelector('#retry') as HTMLButtonElement).onclick = () => retry();
  (wrap.querySelector('#out') as HTMLButtonElement).onclick = async () => {
    await sb.auth.signOut();
    showAuth();
  };
}

// ---------------------------------------------------------------------------
// TOTP enrollment (first time). Only reachable when SKIP_MFA = false.
// ---------------------------------------------------------------------------
async function showEnroll(shellMsg?: string) {
  app.innerHTML =
    '<div class="auth-wrap"><div class="auth-card">جارٍ تجهيز التحقق بخطوة إضافية…</div></div>';

  // التفعيل المهجور يُنشئ عاملًا غير موثّق في كل محاولة؛ ننظّفها قبل الإنشاء
  // حتى لا تتراكم عوامل يتيمة على الحساب.
  const { data: factorsData, error: listError } = await (sb as any).mfa.listFactors();
  if (listError) {
    showLoadError(listError.message ?? String(listError), showEnroll);
    return;
  }
  const pendingFactors = ((factorsData?.all ?? []) as any[]).filter(
    (f) => f.status !== 'verified',
  );
  for (const pending of pendingFactors) {
    const { error: unenrollError } = await (sb as any).mfa.unenroll({
      factorId: pending.id,
    });
    if (unenrollError) {
      showLoadError(unenrollError.message ?? String(unenrollError), showEnroll);
      return;
    }
  }

  const { data, error } = await (sb as any).mfa.enroll({
    factorType: 'totp',
    friendlyName: 'mahwar-admin',
  });
  if (error) {
    app.innerHTML = '';
    const wrap = appEl();
    wrap.className = 'auth-wrap';
    wrap.innerHTML = `<div class="auth-card"><h1>خطأ</h1><div class="sub">${esc(error.message)}</div><button id="out">تسجيل خروج</button></div>`;
    app.appendChild(wrap);
    (wrap.querySelector('#out') as HTMLButtonElement).onclick = async () => {
      await sb.auth.signOut();
      showAuth();
    };
    return;
  }

  const totp = (data as any).totp ?? {};
  const qrSvg: string = totp.qr_code ?? '';
  const secret: string = totp.secret ?? '';

  app.innerHTML = '';
  const wrap = appEl();
  wrap.className = 'auth-wrap';
  wrap.innerHTML = `
    <div class="auth-card">
      <h1>ضبط التحقق بخطوة إضافية</h1>
      ${shellMsg ? `<div class="msg warn show">${esc(shellMsg)}</div>` : ''}
      <div class="sub">
        1) افتح تطبيق المصادقة (Google Authenticator أو مشابه) وامسح الرمز.
        2) <b>كرّر الخطوة على جهاز تاني</b> بإدخال الكود اليدوي تحت — Supabase ما عنده أكواد استرجاع.
        3) أدخل الكود الحالي هنا لتتمييع.
      </div>
      <div class="qr center hidden" id="qr">${qrSvg}</div>
      <div class="field">
        <label>الكود اليدوي (أدخله كزر إضافة في التطبيق على جهازين)</label>
        <input id="secret" value="${esc(secret)}" readonly dir="ltr" style="font-family: monospace" />
      </div>
      <div class="field">
        <label>الكود المكوّن من 6 أرقام</label>
        <input id="code" inputmode="numeric" maxlength="6" placeholder="123456" dir="ltr" />
      </div>
      <button id="confirm" style="width:100%">تحقق وفعّل</button>
      <div class="msg err" id="err"></div>
    </div>`;
  app.appendChild(wrap);

  const qrBox = wrap.querySelector('#qr') as HTMLDivElement;
  if (qrSvg.startsWith('<svg')) qrBox.classList.remove('hidden');

  (wrap.querySelector('#confirm') as HTMLButtonElement).onclick = async () => {
    const code = (wrap.querySelector('#code') as HTMLInputElement).value.trim();
    const err = wrap.querySelector('#err') as HTMLDivElement;
    if (!/^\d{6}$/.test(code)) {
      err.textContent = 'دخّل 6 أرقام';
      err.className = 'msg err show';
      return;
    }
    try {
      const challenge = await (sb as any).mfa.challenge({ factorId: data.id });
      const { error: vErr } = await (sb as any).mfa.verify({
        factorId: data.id,
        challengeId: (challenge.data as any).id,
        code,
      });
      if (vErr) throw vErr;
      boot();
    } catch (e: any) {
      err.textContent = e.message ?? String(e);
      err.className = 'msg err show';
    }
  };
}

// ---------------------------------------------------------------------------
// AAL verify (factor already enrolled, session still aal1).
// ---------------------------------------------------------------------------
async function showAalVerify() {
  app.innerHTML = '<div class="auth-wrap"><div class="auth-card">جارٍ الفحص…</div></div>';
  const { data: factorsData, error } = await (sb as any).mfa.listFactors();
  if (error) {
    // خطأ في القراءة لا يعني عدم وجود عامل: لا نوجّه إلى شاشة التفعيل.
    showLoadError(error.message ?? String(error), showAalVerify);
    return;
  }
  const factors = ((factorsData?.all ?? []) as any[]).filter(
    (f) => f.factor_type === 'totp' && f.status === 'verified',
  );
  const factor = (factors[0] ?? null) as any;
  if (!factor) {
    await showEnroll();
    return;
  }

  app.innerHTML = '';
  const wrap = appEl();
  wrap.className = 'auth-wrap';
  wrap.innerHTML = `
    <div class="auth-card">
      <h1>تحقق بخطوة إضافية</h1>
      <div class="sub">دخّل الكود المؤقت (6 أرقام) من تطبيق المصادقة.</div>
      <div class="field"><input id="code" inputmode="numeric" maxlength="6" placeholder="123456" dir="ltr" /></div>
      <button id="confirm" style="width:100%">تحقق</button>
      <div class="msg err" id="err"></div>
      <button class="linklike" id="out">تسجيل الخروج</button>
    </div>`;
  app.appendChild(wrap);

  (wrap.querySelector('#confirm') as HTMLButtonElement).onclick = async () => {
    const code = (wrap.querySelector('#code') as HTMLInputElement).value.trim();
    const err = wrap.querySelector('#err') as HTMLDivElement;
    try {
      const challenge = await (sb as any).mfa.challenge({ factorId: factor.id });
      const { error } = await (sb as any).mfa.verify({
        factorId: factor.id,
        challengeId: (challenge.data as any).id,
        code,
      });
      if (error) throw error;
      boot();
    } catch (e: any) {
      err.textContent = e.message ?? String(e);
      err.className = 'msg err show';
    }
  };
  (wrap.querySelector('#out') as HTMLButtonElement).onclick = async () => {
    await sb.auth.signOut();
    showAuth();
  };
}

// ---------------------------------------------------------------------------
// Dashboard shell: sidebar + views (overview / users / exports) + drawer.
// ---------------------------------------------------------------------------
const listState = {
  page: 1,
  pageSize: 25,
  search: '' as string,
  role: '' as string,
  totalPages: 1,
  total: 0,
};

const ORDER_STATUS: Record<string, { label: string; cls: string }> = {
  pending: { label: 'بانتظار موافقة', cls: 'st-pending' },
  priced: { label: 'تم التسعير', cls: 'st-priced' },
  confirmed: { label: 'مؤكد', cls: 'st-confirmed' },
  rejected_by_provider: { label: 'مرفوض من مقدم الخدمة', cls: 'st-rejected' },
  rejected_by_owner: { label: 'مرفوض من المالك', cls: 'st-rejected' },
  cancelled: { label: 'مُلغى', cls: 'st-cancelled' },
  completed: { label: 'مكتمل', cls: 'st-completed' },
};

const ROLE_LABEL: Record<string, string> = {
  car_owner: 'مالك سيارة',
  provider: 'مقدم خدمة',
};

// ---------------------------------------------------------------------------
// Navigation helper: تبديل الصفحة مع تمرير فلاتر (يُعاد تحميل الصفحة الهدف
// داخل nav-click handler — لذلك ضبط state هنا يكفي، القيم تظهر في الأدوات).
// ---------------------------------------------------------------------------
type GoPrefs = { role?: string; search?: string; status?: string };

function goTo(view: string, prefs: GoPrefs = {}) {
  if (view === 'users') {
    listState.page = 1;
    listState.role = prefs.role ?? '';
    listState.search = prefs.search ?? '';
  } else if (view === 'orders') {
    ordersState.page = 1;
    ordersState.status = prefs.status ?? '';
    ordersState.search = prefs.search ?? '';
  }
  document
    .querySelector<HTMLElement>(`.nav-item[data-view="${view}"]`)
    ?.click();
}

function showDashboard() {
  app.innerHTML = '';
  const root = appEl();
  root.className = 'shell';
  root.innerHTML = `
    <aside class="side">
      <div class="brand">
        <span class="brand-mark">${ICONS.gauge}</span>
        <div>
          <div class="brand-name">برج مراقبة محور</div>
          <div class="brand-sub">لوحة الأدمن</div>
        </div>
      </div>

      <nav class="nav">
        <div class="nav-group">عام</div>
        <button class="nav-item active" data-view="overview">${ICONS.gauge}<span>لوحة القياس</span></button>
        <button class="nav-item" data-view="analytics">${ICONS.chart}<span>التحليلات</span></button>
        <button class="nav-item" data-view="users">${ICONS.users}<span>المستخدمون</span></button>
        <button class="nav-item" data-view="orders">${ICONS.clipboard}<span>الطلبات</span></button>
        <button class="nav-item" data-view="bans">${ICONS.shield}<span>سجل الحظر</span></button>
        <button class="nav-item" data-view="messages">${ICONS.bell}<span>الرسائل والإشعارات</span></button>
        <button class="nav-item" data-view="exports">${ICONS.download}<span>التصدير</span></button>
      </nav>

      <div class="side-foot">
        <div class="who" id="who"></div>
        <button class="nav-item logout" id="logout">${ICONS.logout}<span>تسجيل الخروج</span></button>
      </div>
    </aside>

    <main class="main">
      <section class="view" id="view-overview"></section>
      <section class="view hidden" id="view-analytics"></section>
      <section class="view hidden" id="view-users"></section>
      <section class="view hidden" id="view-orders"></section>
      <section class="view hidden" id="view-bans"></section>
      <section class="view hidden" id="view-messages"></section>
      <section class="view hidden" id="view-exports"></section>
    </main>

    <div class="drawer-overlay hidden" id="drawer-overlay"><div class="drawer" id="drawer"></div></div>
  `;
  app.appendChild(root);

  sb.auth.getUser().then(({ data }) => {
    (root.querySelector('#who') as HTMLElement).textContent = data?.user?.email ?? '';
  });

  (root.querySelector('#logout') as HTMLButtonElement).onclick = async () => {
    await sb.auth.signOut();
    showAuth();
  };

  const navButtons = Array.from(root.querySelectorAll('.nav-item[data-view]')) as HTMLButtonElement[];
  const viewRenderers: Record<string, (el: HTMLElement) => void> = {
    overview: (el) => void renderOverview(el),
    analytics: (el) => void renderAnalytics(el),
    users: renderUsers,
    orders: renderOrders,
    bans: renderBans,
    messages: renderMessages,
    exports: renderExports,
  };
  navButtons.forEach((b) => {
    b.onclick = () => {
      navButtons.forEach((x) => x.classList.remove('active'));
      b.classList.add('active');
      const v = b.dataset.view!;
      root.querySelectorAll('.view').forEach((el) => el.classList.add('hidden'));
      const section = root.querySelector(`#view-${v}`) as HTMLElement;
      section.classList.remove('hidden');
      // تدفق الحيّة دائما: كل زيارةللصفحة تعيد ال rendering لازمة لأقدح الأدمن
      // (خصوصًا من الاختصارات المauche لصفحة بتقييد الن).
      viewRenderers[v]?.(section);
    };
  });

  renderOverview(root.querySelector('#view-overview') as HTMLElement);
  renderUsers(root.querySelector('#view-users') as HTMLElement);
  renderOrders(root.querySelector('#view-orders') as HTMLElement);
  renderBans(root.querySelector('#view-bans') as HTMLElement);
  renderMessages(root.querySelector('#view-messages') as HTMLElement);
  renderExports(root.querySelector('#view-exports') as HTMLElement);
}

// ---------------------------------------------------------------------------
// View: overview (stat cards + orders-by-status chips + latest activity).
// ---------------------------------------------------------------------------
async function renderOverview(v: HTMLElement) {
  v.innerHTML = `
    <h1 class="view-title">${ICONS.gauge} لوحة القياس</h1>
    <div class="cards" id="ov-cards"></div>
    <div class="ov-grid">
      <div>
        <div class="panel">
          <h2>${ICONS.clipboard} الطلبات بالحالة</h2>
          <div id="ov-status" class="status-grid"><span class="muted">جارٍ التحميل…</span></div>
        </div>

        <div class="panel">
          <h2>${ICONS.bell} أحدث الطلبات (آخر 5)</h2>
          <div id="ov-orders"><span class="muted">جارٍ التحميل…</span></div>
        </div>
      </div>
      <div>
        <div class="panel">
          <h2>${ICONS.users} أحدث المستخدمين المنضمين (آخر 5)</h2>
          <div id="ov-users"><span class="muted">جارٍ التحميل…</span></div>
        </div>

        <div class="panel">
          <h2>${ICONS.shield} حالة النظام</h2>
          <div id="ov-system"><span class="muted">جارٍ التحميل…</span></div>
          <div class="btn-row">
            <button class="secondary" data-goto="analytics">${ICONS.chart} التحليلات</button>
            <button class="secondary" data-goto="users">${ICONS.users} المستخدمون</button>
            <button class="secondary" data-goto="exports">${ICONS.download} التصدير</button>
          </div>
        </div>
      </div>
    </div>`;

  v.querySelectorAll('[data-goto]').forEach((b) => {
    (b as HTMLButtonElement).onclick = () => {
      (
        document.querySelector(`.nav-item[data-view="${(b as HTMLElement).dataset.goto}"]`) as
          | HTMLButtonElement
          | null
      )?.click();
    };
  });

  try {
    const [c, act] = await Promise.all([
      rpcSilent('admin_dashboard_counts'),
      rpcSilent('admin_recent_activity').catch(() => null),
    ]);

    // ---- stat cards (كل بطاقة اختصار لصفحتها التفصيلية) ---------------------
    const cards: { v: any; k: string; i: string; cls: string; go: string; p?: GoPrefs }[] = [
      { v: c.users_total, k: 'إجمالي المستخدمين', i: ICONS.users, cls: 'ac-blue', go: 'users' },
      { v: c.users_owners, k: 'أصحاب سيارات', i: ICONS.car, cls: 'ac-teal', go: 'users', p: { role: 'car_owner' } },
      { v: c.users_providers, k: 'مقدمو خدمة', i: ICONS.wrench, cls: 'ac-orange', go: 'users', p: { role: 'provider' } },
      { v: c.providers_online, k: 'متصلون الآن (مقدمي الخدمة)', i: ICONS.pin, cls: 'ac-green', go: 'users', p: { role: 'provider' } },
      { v: c.users_created_24h, k: 'مستخدمون جدد (24 ساعة)', i: ICONS.bell, cls: 'ac-purple', go: 'users' },
      { v: c.users_created_7d, k: 'مستخدمون جدد (7 أيام)', i: ICONS.bell, cls: 'ac-purple', go: 'users' },
      { v: c.orders_total, k: 'إجمالي الطلبات', i: ICONS.clipboard, cls: 'ac-blue', go: 'orders' },
      { v: c.orders_created_24h, k: 'طلبات (24 ساعة)', i: ICONS.clipboard, cls: 'ac-teal', go: 'orders' },
      { v: c.orders_created_7d, k: 'طلبات (7 أيام)', i: ICONS.clipboard, cls: 'ac-teal', go: 'orders' },
      { v: c.notifications_total, k: 'الإشعارات', i: ICONS.bell, cls: 'ac-orange', go: 'messages' },
    ];
    (v.querySelector('#ov-cards') as HTMLElement).innerHTML = cards
      .map(
        (x) =>
          `<div class="card clickable ${x.cls}" data-go="${x.go}" data-role="${esc(x.p?.role ?? '')}" title="اضغط لفتح التفاصيل"><div class="card-icon">${x.i}</div><div><div class="v">${esc(x.v ?? 0)}</div><div class="k">${esc(x.k)}</div></div></div>`
      )
      .join('');
    (v.querySelector('#ov-cards') as HTMLElement)
      .querySelectorAll<HTMLElement>('.card[data-go]')
      .forEach((card) => {
        card.onclick = () =>
          goTo(card.dataset.go!, {
            role: card.dataset.role || undefined,
          });
      });

    // ---- orders by status (كل chip اختصار لصفحة الطلبات بالفلتر) ------------
    const st = v.querySelector('#ov-status') as HTMLElement;
    st.innerHTML =
      Object.entries(c.orders_by_status ?? {})
        .map(([k, val]) => {
          const meta = ORDER_STATUS[k] ?? { label: k, cls: '' };
          return `<div class="status-chip clickable ${meta.cls}" data-status="${esc(k)}" title="اضغط لعرض هذه الطلبات في صفحة الطلبات"><span>${esc(meta.label)}</span><b>${esc(val ?? 0)}</b></div>`;
        })
        .join('') || '<span class="muted">لا طلبات</span>';
    st.querySelectorAll<HTMLElement>('.status-chip.clickable').forEach((chip) => {
      chip.onclick = () => goTo('orders', { status: chip.dataset.status ?? '' });
    });

    // ---- latest orders ------------------------------------------------------
    const ordersBox = v.querySelector('#ov-orders') as HTMLElement;
    ordersBox.innerHTML =
      (act?.latest_orders ?? [])
        .map(
          (o: any) =>
            `<div class="list-item"><span class="badge ${ORDER_STATUS[o.status]?.cls ?? ''}">${esc(ORDER_STATUS[o.status]?.label ?? o.status)}</span>
              <span>${esc(o.service ?? '—')}</span>
              <span class="muted">· ${esc(o.owner_name ?? '—')} ← ${esc(o.provider_name ?? '—')}</span>
              ${o.offered_price != null ? `<b>${esc(o.offered_price)} جنيه</b>` : ''}
              <span class="muted small">· ${fmt(o.created_at)}</span></div>`
        )
        .join('') || '<div class="muted">لا طلبات بعد</div>';

    // ---- latest users -------------------------------------------------------
    const usersBox = v.querySelector('#ov-users') as HTMLElement;
    usersBox.innerHTML =
      (act?.latest_users ?? [])
        .map(
          (u: any) =>
            `<div class="list-item clickable" data-uid="${esc(u.id)}">
              ${u.role === 'provider' ? '<span class="badge provider">مقدم خدمة</span>' : '<span class="badge owner">مالك سيارة</span>'}
              <span>${esc(u.full_name ?? '—')}</span>
              <span dir="ltr" class="muted small">${esc(u.phone ?? '')}</span>
              <span class="muted small">· ${fmt(u.created_at)}</span>
            </div>`
        )
        .join('') || '<div class="muted">لا مستخدمين</div>';
    usersBox.querySelectorAll('[data-uid]').forEach((el) => {
      (el as HTMLElement).onclick = () => openDrawer((el as HTMLElement).dataset.uid!);
    });

    // ---- system state -------------------------------------------------------
    (v.querySelector('#ov-system') as HTMLElement).innerHTML = `
      <div class="list-item">${ICONS.shield} <span>قائمة الأدمن: <b>1 حساب</b> (حسابك)</span></div>
      ${SKIP_MFA
        ? '<div class="list-item warn-item">التحقق بخطوة إضافية معطّل في وضع التطوير المحلي فقط (VITE_SKIP_MFA=true).</div>'
        : '<div class="list-item">الحماية بخطوة إضافية مفعّلة</div>'}
      <div class="list-item">الاتصال: مشروع <code dir="ltr" class="tiny">trgesfzoj</code> · البيانات حية من قاعدة البيانات</div>`;
  } catch (e: any) {
    (v.querySelector('#ov-cards') as HTMLElement).innerHTML =
      `<div class="card"><div class="k">${esc(e?.message ?? 'خطأ')}</div></div>`;
  }
}

// ---------------------------------------------------------------------------
// View: analytics (timeline charts + UX funnel + retention + page paths).
// ---------------------------------------------------------------------------
const analyticsState = { days: 14, role: 'car_owner' };

const PATH_LABELS: Record<string, string> = {
  '/splash': 'السبلاش',
  '/onboarding': 'التعريف',
  '/select-user-type': 'اختيار النوع',
  '/login': 'تسجيل الدخول',
  '/signup': 'إنشاء حساب',
  '/forgot-password': 'استعادة كلمة السر',
  '/set-new-password': 'كلمة سر جديدة',
  '/otp-verify': 'توثيق الهاتف',
  '/home/owner': 'الرئيسية (عميل)',
  '/home/provider': 'الرئيسية (مقدم)',
  '/request/create': 'إنشاء طلب',
  '/request/track': 'متابعة الطلب',
  '/request/providers': 'قائمة المقدمين',
  '/request/provider-details': 'تفاصيل مقدم',
  '/request/quote': 'عرض السعر',
  '/request/map': 'خريطة الموقع',
  '/orders/owner': 'طلباتي (عميل)',
  '/orders/provider': 'طلباتي (مقدم)',
  '/notifications': 'الإشعارات',
  '/notification/detail': 'تفصيل إشعار',
  '/profile': 'الملف الشخصي',
  '/profile/edit': 'تعديل البيانات',
  '/profile/cars': 'سياراتي',
  '/profile/change-password': 'تغيير كلمة السر',
  '/provider/workshop': 'بيانات الورشة',
  '/provider/specialties': 'التخصصات',
  '/provider/schedule': 'مواعيد العمل',
  '/profile/avatar': 'الصورة الشخصية',
  '/terms': 'الشروط',
  '/privacy': 'الخصوصية',
};

function pathLabel(s: string): string {
  return PATH_LABELS[s] ?? s;
}

function fmtDur(sec: number): string {
  if (!sec || sec <= 0) return '—';
  const m = Math.floor(sec / 60);
  const s = Math.round(sec % 60);
  return m > 0 ? `${m} د ${s} ث` : `${s} ث`;
}

function svgBars(values: number[], labels: string[], color: string): string {
  const max = Math.max(1, ...values);
  const n = values.length;
  const w = 100 / n;
  const bars = values
    .map((val, i) => {
      const h = Math.max((val / max) * 30, val > 0 ? 1.4 : 0);
      const x = i * w + w * 0.15;
      const bw = w * 0.7;
      const y = 33 - h;
      return `<rect x="${x.toFixed(2)}" y="${y.toFixed(2)}" width="${bw.toFixed(2)}" height="${h.toFixed(2)}" fill="${color}" rx="0.5"><title>${labels[i]}: ${val}</title></rect>` +
        (val > 0 ? `<text x="${(x + bw / 2).toFixed(2)}" y="${(y - 1.2).toFixed(2)}" font-size="2.5" text-anchor="middle" fill="currentColor" opacity=".75">${val}</text>` : '');
    })
    .join('');
  const axis = labels
    .map((l, i) => `${i % 2 === 0 ? `<text x="${(i * w + w / 2).toFixed(2)}" y="40" font-size="2.5" text-anchor="middle" fill="currentColor" opacity=".5">${l}</text>` : ''}`)
    .join('');
  return `<svg viewBox="0 0 100 42" preserveAspectRatio="none" style="width:100%;height:170px">${bars}${axis}</svg>`;
}

function funnelRow(label: string, count: number, base: number, color = 'var(--accent)'): string {
  const pct = base > 0 ? Math.round((count / base) * 100) : 0;
  return `<div class="funnel-row">
    <span class="f-label">${esc(label)}</span>
    <div class="f-bar"><span style="width:${Math.min(pct, 100)}%;background:${color}"></span></div>
    <b>${esc(count)}</b><span class="muted small">${pct}%</span>
  </div>`;
}

function renderAnalytics(v: HTMLElement) {
  const d = analyticsState.days;
  v.innerHTML = `
    <h1 class="view-title">${ICONS.chart} التحليلات وتجربة المستخدم</h1>

    <div class="panel">
      <div class="panel-head">
        <h2>${ICONS.chart} المخطط الزمني</h2>
        <div class="btn-row">
          <button class="chip-btn ${d === 7 ? 'active' : ''}" data-days="7">7 أيام</button>
          <button class="chip-btn ${d === 14 ? 'active' : ''}" data-days="14">14 يوم</button>
          <button class="chip-btn ${d === 30 ? 'active' : ''}" data-days="30">30 يوم</button>
        </div>
      </div>
      <div class="charts-grid">
        <div><h3>مستخدمون جدد لكل يوم</h3><div id="a-chart-users"><span class="muted">جارٍ التحميل…</span></div></div>
        <div><h3>طلبات جديدة لكل يوم</h3><div id="a-chart-orders"><span class="muted">جارٍ التحميل…</span></div></div>
        <div><h3>طلبات مكتملة لكل يوم</h3><div id="a-chart-completed"><span class="muted">جارٍ التحميل…</span></div></div>
        <div><h3>إشعارات مرسلة لكل يوم</h3><div id="a-chart-notifs"><span class="muted">جارٍ التحميل…</span></div></div>
      </div>
    </div>

    <div class="cards" id="a-ret"></div>

    <div class="panel">
      <h2>${ICONS.users} قمع تجربة المستخدم (من الأنضمام إلى إتمام الطلب)</h2>
      <div class="sub">كل صف نسبته من إجمالي المستخدمين — لو الرقم صغير فمكان مانع في التجربة قبل منحس.</div>
      <div id="a-funnel"><span class="muted">جارٍ التحميل…</span></div>
    </div>

    <div class="panel">
      <div class="panel-head">
        <h2>${ICONS.clipboard} مسارات المستخدمين داخل التطبيق</h2>
        <div class="btn-row">
          <button class="chip-btn ${analyticsState.role === 'car_owner' ? 'active' : ''}" data-path-role="car_owner">العملاء</button>
          <button class="chip-btn ${analyticsState.role === 'provider' ? 'active' : ''}" data-path-role="provider">مقدمو الخدمة</button>
        </div>
      </div>
      <div class="sub">أي شاشة يتجه إليها المستخدم وكم يقضي تحت كل شاشة — والانتقالات الأكثر شائعًا (شاشة ← شاشة).</div>
      <div id="a-paths"><span class="muted">جارٍ التحميل…</span></div>
    </div>`;

  v.querySelectorAll<HTMLButtonElement>('.chip-btn[data-days]').forEach((b) => {
    b.onclick = () => {
      analyticsState.days = Number(b.dataset.days);
      renderAnalytics(v);
    };
  });

  v.querySelectorAll<HTMLButtonElement>('.chip-btn[data-path-role]').forEach((b) => {
    b.onclick = () => {
      analyticsState.role = b.dataset.pathRole!;
      renderAnalytics(v);
    };
  });

  loadAnalytics(v);
}

async function loadPagePaths(v: HTMLElement) {
  const el = v.querySelector('#a-paths') as HTMLElement | null;
  if (!el) return;
  el.innerHTML = '<span class="muted">جارٍ التحميل…</span>';
  try {
    const data: any = await rpcSilent('admin_page_paths');
    const role = data?.roles?.[analyticsState.role];
    const screens: any[] = role?.screens ?? [];
    const paths: any[] = role?.paths ?? [];

    // عدادات الأحداث لكل دور → تظهر على أزرار التبويب نفسها، فمش هتضيع
    // البيانات تحت تبويب مش مفتوح.
    const counts: Record<string, number> = {
      car_owner: Number(data?.roles?.car_owner?.events ?? 0),
      provider: Number(data?.roles?.provider?.events ?? 0),
    };
    v.querySelectorAll<HTMLButtonElement>('.chip-btn[data-path-role]').forEach((b) => {
      const r = b.dataset.pathRole!;
      b.textContent = `${r === 'car_owner' ? 'العملاء' : 'مقدمو الخدمة'} (${counts[r] ?? 0})`;
      b.classList.toggle('active', analyticsState.role === r);
    });

    if (!role || (screens.length === 0 && paths.length === 0)) {
      el.innerHTML = `<div class="muted">لا زيارات مسجَّلة لتبويب «${analyticsState.role === 'car_owner' ? 'العملاء' : 'مقدمو الخدمة'}» لسه.<br/>بيانات تاني دور موجودة فوق في الأزرار (الرقم بين القوسين) — اضغط عليه لعرضها.</div>`;
      return;
    }
    el.innerHTML = `
      <div class="path-summary">
        <span>${ICONS.users} ${esc(role.users ?? 0)} مستخدم متتبَّع</span>
        <span>${ICONS.clipboard} ${esc(role.events ?? 0)} زيارة شاشة</span>
      </div>
      <h3 class="muted">الشاشات (زيارات + متوسط الوقت)</h3>
      ${screens.length ? `<div class="table-wrap"><table>
        <thead><tr><th>الشاشة</th><th>زيارات</th><th>متوسط</th><th>إجمالي</th></tr></thead>
        <tbody>${screens
          .map(
            (s) => `<tr>
              <td>${esc(pathLabel(String(s.screen)))}</td>
              <td>${esc(s.visits ?? 0)}</td>
              <td>${esc(fmtDur(Number(s.avg_sec ?? 0)))}</td>
              <td>${esc(fmtDur(Number(s.total_sec ?? 0)))}</td>
            </tr>`
          )
          .join('')}</tbody></table></div>`
        : '<div class="muted">لا زيارات</div>'}
      <h3 class="muted">أشهر الانتقالات</h3>
      ${paths.length
        ? `<div class="path-pills">${paths
            .slice(0, 15)
            .map(
              (p) =>
                `<div class="path-pill"><span>${esc(pathLabel(String(p.from)))} ← ${esc(pathLabel(String(p.to)))}</span><b>${esc(p.count ?? 0)}×</b><span class="muted small">متوسط ${esc(fmtDur(Number(p.avg_sec ?? 0)))}</span></div>`
            )
            .join('')}</div>`
        : '<div class="muted">لا انتقالات</div>'}`;
  } catch (e: any) {
    el.innerHTML = `<div class="muted">${esc(e?.message ?? 'خطأ')}</div>`;
  }
}

async function loadAnalytics(v: HTMLElement) {
  const PH = '<span class="muted">جارٍ التحميل…</span>';
  const charts: Record<string, HTMLElement | null> = {
    users: v.querySelector('#a-chart-users'),
    orders: v.querySelector('#a-chart-orders'),
    completed: v.querySelector('#a-chart-completed'),
    notifs: v.querySelector('#a-chart-notifs'),
    ret: v.querySelector('#a-ret'),
    funnel: v.querySelector('#a-funnel'),
  };
  void loadPagePaths(v); // مسارات المستخدمين — مستقلة عن المخططات الزمنية
  Object.values(charts).forEach((c) => c && (c.innerHTML = PH));
  try {
    const a: any = await rpcSilent('admin_dashboard_analytics');
    const series: any[] = a.series ?? [];
    const labels = series.map((s) => {
      const dt = new Date(s.day + 'T00:00:00Z');
      return `${dt.getUTCDate()}/${dt.getUTCMonth() + 1}`;
    });
    const n = Math.min(series.length, analyticsState.days);
    const sl = series.slice(-n);
    const ll = labels.slice(-n);

    if (charts.users)
      charts.users.innerHTML = svgBars(
        sl.map((s) => Number(s.users_created ?? 0)), ll, '#4f8cff');
    if (charts.orders)
      charts.orders.innerHTML = svgBars(
        sl.map((s) => Number(s.orders_created ?? 0)), ll, '#ff8a4f');
    if (charts.completed)
      charts.completed.innerHTML = svgBars(
        sl.map((s) => Number(s.orders_completed ?? 0)), ll, '#2fbf8f');
    if (charts.notifs)
      charts.notifs.innerHTML = svgBars(
        sl.map((s) => Number(s.notifications_sent ?? 0)), ll, '#a06bff');

    const ret = a.retention ?? {};
    if (charts.ret) {
      const cards = [
        { v: ret.last_1d ?? 0, k: 'دخلت آخر 24 ساعة', i: ICONS.pin, cls: 'ac-green' },
        { v: ret.last_7d ?? 0, k: 'دخلت آخر 7 أيام', i: ICONS.users, cls: 'ac-teal' },
        { v: ret.last_30d ?? 0, k: 'دخلت آخر 30 يوم', i: ICONS.users, cls: 'ac-blue' },
        { v: ret.online_providers ?? 0, k: 'متصلون الآن (مقدمو)', i: ICONS.wrench, cls: 'ac-orange' },
        { v: ret.banned ?? 0, k: 'محظورون حاليًا', i: ICONS.shield, cls: 'ac-red' },
      ];
      charts.ret.innerHTML = cards
        .map(
          (x) =>
            `<div class="card ${x.cls}"><div class="card-icon">${x.i}</div><div><div class="v">${esc(x.v ?? 0)}</div><div class="k">${esc(x.k)}</div></div></div>`
        )
        .join('');
    }

    const f = a.funnel ?? {};
    const total = Number(f.registered ?? 0);
    if (charts.funnel) {
      charts.funnel.innerHTML = total === 0
        ? '<div class="muted">لا مستخدمين</div>'
        : [
            funnelRow('سجّلوا حسابًا', f.registered ?? 0, total, '#4f8cff'),
            funnelRow('عندهم رقم هاتف مؤكد', f.phone_verified ?? 0, total, '#2fbf8f'),
            funnelRow('دخلوا آخر 7 أيام', f.active_last7d ?? 0, total, '#a06bff'),
            funnelRow('طلبوا خدمة قبلًا', f.made_order ?? 0, total, '#ff8a4f'),
            funnelRow('طلب واحد اكتمل لهم', f.completed_order ?? 0, total, '#2fbf8f'),
            funnelRow('قيموا خدمةً سابقة', f.rated ?? 0, total, '#ffd166'),
          ].join('');
    }
  } catch (e: any) {
    Object.values(charts).forEach(
      (c) => c && (c.innerHTML = `<div class="muted">${esc(e?.message ?? 'خطأ')}</div>`)
    );
  }
}

// ---------------------------------------------------------------------------
// View: users (filters + table + pager). Row click opens the drawer.
// ---------------------------------------------------------------------------
function renderUsers(v: HTMLElement) {
  v.innerHTML = `
    <h1 class="view-title">${ICONS.users} المستخدمون</h1>
    <div class="panel">
      <div class="toolbar">
        <div class="searchbox">${ICONS.search}<input type="text" id="search" value="${esc(listState.search)}" placeholder="بحث بالإسم / الموبايل / الإيميل / الرقم القومي…" /></div>
        <select id="role">
          <option value="" ${listState.role === '' ? 'selected' : ''}>كل الأنواع</option>
          <option value="car_owner" ${listState.role === 'car_owner' ? 'selected' : ''}>مالك سيارة</option>
          <option value="provider" ${listState.role === 'provider' ? 'selected' : ''}>مقدم خدمة</option>
        </select>
        <button id="apply">بحث</button>
      </div>
      <div class="table-wrap"><table>
        <thead><tr>
          <th>الإسم</th><th>الموبايل</th><th>النوع</th><th>الورشة / الحالة</th>
          <th>هاتف مؤكد</th><th>رقم قومي</th><th>طلبات</th><th>الانضمام</th>
        </tr></thead>
        <tbody id="rows"><tr><td class="muted">جارٍ التحميل…</td></tr></tbody>
      </table></div>
      <div class="pager">
        <button class="secondary" id="prev">${ICONS.chevronL}</button>
        <span class="info" id="pageinfo"></span>
        <button class="secondary" id="next">${ICONS.chevronR}</button>
      </div>
    </div>`;

  (v.querySelector('#apply') as HTMLButtonElement).onclick = () => {
    listState.search = (v.querySelector('#search') as HTMLInputElement).value.trim();
    listState.role = (v.querySelector('#role') as HTMLSelectElement).value;
    listState.page = 1;
    loadUsers(v);
  };
  (v.querySelector('#search') as HTMLInputElement).onkeydown = (ev) => {
    if ((ev as KeyboardEvent).key === 'Enter')
      (v.querySelector('#apply') as HTMLButtonElement).click();
  };
  (v.querySelector('#prev') as HTMLButtonElement).onclick = () => {
    if (listState.page > 1) {
      listState.page--;
      loadUsers(v);
    }
  };
  (v.querySelector('#next') as HTMLButtonElement).onclick = () => {
    if (listState.page < listState.totalPages) {
      listState.page++;
      loadUsers(v);
    }
  };

  loadUsers(v);
}

async function loadUsers(v: HTMLElement) {
  const rows = v.querySelector('#rows') as HTMLElement;
  rows.innerHTML = '<tr><td class="muted">جارٍ التحميل…</td></tr>';
  try {
    const data: any[] = await rpcSilent('admin_list_users', {
      p_page: listState.page,
      p_page_size: listState.pageSize,
      p_search: listState.search || null,
      p_role: listState.role || null,
    });
    listState.total = Number(data[0]?.total_count ?? 0);
    listState.totalPages = Math.max(1, Math.ceil(listState.total / listState.pageSize));

    if (!data.length) {
      rows.innerHTML = '<tr><td class="muted">لا نتائج</td></tr>';
    } else {
      rows.innerHTML = data
        .map((u) => {
          const total = (u.orders_as_owner ?? 0) + (u.orders_as_provider ?? 0);
          const roleBadge = u.role === 'provider'
            ? '<span class="badge provider">مقدم خدمة</span>'
            : '<span class="badge owner">مالك سيارة</span>';
          const stateBadge = u.is_online
            ? '<span class="badge online">متصل</span>'
            : '<span class="badge offline">غير متصل</span>';
          const verified = u.phone_verified
            ? '<span class="badge online">مؤكد</span>'
            : '<span class="badge offline">غير مؤكد</span>';
          const nid = u.national_id
            ? `<span dir="ltr">${esc(u.national_id)}</span>`
            : '<span class="muted">—</span>';
          return `<tr data-uid="${esc(u.user_id)}">
            <td>${esc(u.full_name ?? '—')}${u.banned ? ' <span class="badge st-rejected">محظور</span>' : ''}</td>
            <td dir="ltr">${esc(u.phone_number ?? '—')}</td>
            <td>${roleBadge}</td>
            <td>${u.role === 'provider' ? esc(u.workshop_name ?? '—') + ' ' + stateBadge : ''}</td>
            <td>${verified}</td>
            <td>${nid}</td>
            <td class="small">${total} <span class="muted">(${esc(u.orders_as_owner ?? 0)} م / ${esc(u.orders_as_provider ?? 0)} خ)</span></td>
            <td class="small muted">${fmt(u.created_at)}</td>
          </tr>`;
        })
        .join('');
      rows.querySelectorAll('tr[data-uid]').forEach((tr) => {
        (tr as HTMLElement).onclick = () => openDrawer((tr as HTMLElement).dataset.uid!);
      });
    }
    (v.querySelector('#pageinfo') as HTMLElement).textContent =
      `صفحة ${listState.page} من ${listState.totalPages} — إجمالي ${listState.total}`;
  } catch (e: any) {
    rows.innerHTML = `<tr><td class="muted">${esc(e?.message ?? 'خطأ')}</td></tr>`;
  }
}

// ---------------------------------------------------------------------------
// Drawer: user detail overlay with tabs.
// ---------------------------------------------------------------------------
const NOTIF_LABELS: Record<string, string> = {
  new_order: 'طلب جديد وصل',
  order_confirmed: 'تأكيد طلب',
  broadcast: 'طلب عام (broadcast)',
  shift_started: 'بداية شيفت',
  shift_ended: 'نهاية شيفت',
};

const notifRow = (n: any) => `
  <div class="list-item">
    <span class="badge ${n.is_read ? '' : 'unread'}">${esc(NOTIF_LABELS[n.type] ?? n.type)}</span>
    ${n.order_id ? `<code dir="ltr" class="tiny">${esc(n.order_id.slice(0, 8))}…</code>` : ''}
    · ${fmt(n.created_at)}
  </div>`;

const orderRow = (o: any) => {
  const st = ORDER_STATUS[o.status] ?? { label: o.status, cls: '' };
  return `<div class="list-item">
    <span class="badge ${st.cls}">${esc(st.label)}</span>
    ${esc(o.service_type ?? '—')}
    · ${o.offered_price != null ? esc(o.offered_price) + ' جنيه' : '<span class="muted">بدون سعر</span>'}
    <span class="muted small">· ${fmt(o.created_at)}</span>
  </div>`;
};

async function openDrawer(uid: string) {
  const overlay = document.getElementById('drawer-overlay') as HTMLElement;
  const drawer = document.getElementById('drawer') as HTMLElement;
  overlay.classList.remove('hidden');
  document.body.style.overflow = 'hidden';
  drawer.innerHTML = '<div class="drawer-loading">جارٍ التحميل…</div>';
  overlay.onclick = (ev) => {
    if (ev.target === overlay) closeDrawer();
  };

  try {
    const [d, notif] = await Promise.all([
      rpcSilent('admin_get_user', { p_user_id: uid }),
      rpcSilent('admin_notification_activity', { p_user_id: uid }).catch(() => null),
    ]);
    renderDrawer(drawer, d, notif, uid);
  } catch (e: any) {
    drawer.innerHTML = `<div class="drawer-loading"><div class="msg err show">${esc(e?.message ?? 'خطأ')}</div></div>`;
  }
}

function closeDrawer() {
  const overlay = document.getElementById('drawer-overlay') as HTMLElement;
  if (!overlay) return;
  overlay.classList.add('hidden');
  (document.getElementById('drawer') as HTMLElement).innerHTML = '';
  document.body.style.overflow = '';
}

function renderDrawer(drawer: HTMLElement, d: any, notif: any, uid: string) {
  const p = d.profile ?? {};
  const a = d.auth ?? {};
  const prov = d.provider ?? null;
  const isBannedNow = a.banned_until && new Date(a.banned_until) > new Date();

  const tabs: { id: string; label: string; icon: string; html: string }[] = [];

  tabs.push({
    id: 'basics',
    label: 'بيانات',
    icon: ICONS.users,
    html: `
      <dl class="kv">
        <dt>الإسم</dt><dd>${esc(p.full_name ?? '—')}</dd>
        <dt>الموبايل</dt><dd dir="ltr">${esc(p.phone_number ?? '—')}</dd>
        <dt>الإيميل</dt><dd dir="ltr">${esc(p.email ?? a.email ?? '—')}</dd>
        <dt>النوع</dt><dd>${esc(ROLE_LABEL[p.role] ?? p.role ?? '—')}</dd>
        <dt>الرقم القومي</dt><dd dir="ltr">${esc(p.national_id ?? '—')}</dd>
        <dt>هاتف مؤكد</dt><dd>${p.phone_verified_at ? 'نعم (' + fmt(p.phone_verified_at) + ')' : 'لا'}</dd>
        <dt>تاريخ الانضمام</dt><dd>${fmt(p.created_at)}</dd>
        <dt>آخر دخول</dt><dd>${fmt(a.last_sign_in_at)}</dd>
        <dt>اللغة</dt><dd>${esc(p.language ?? '—')}</dd>
        <dt>الحساب أُنشئ</dt><dd>${fmt(a.created_at)}</dd>
      </dl>
      <h3>${ICONS.shield} إجراءات الأدمن</h3>
      <div class="actions-row">
        ${
          isBannedNow
            ? `<span class="badge st-rejected">الحساب محظور (${fmt(a.banned_until)})</span>
               <button class="secondary" data-action="unban">رفع الحظر</button>`
            : `<select id="ban-duration">
                 <option value="">دائم</option>
                 <option value="1">يوم واحد</option>
                 <option value="3">3 أيام</option>
                 <option value="7">أسبوع</option>
                 <option value="14">أسبوعين</option>
                 <option value="30">شهر (30 يوم)</option>
               </select>
               <button class="danger" data-action="ban">حظر الحساب</button>
               <span class="muted small">يمنع الدخول وكل الصلاحيات حتى رفع الحظر أو انتهاء المدة، والسبب يُسجل بالاسم.</span>`
        }
      </div>`,
  });

  tabs.push({
    id: 'provider',
    label: 'سيارات ومقدم',
    icon: ICONS.car,
    html: `
      <h3>${ICONS.car} سيارات</h3>
      ${(d.cars ?? [])
        .map(
          (c: any) =>
            `<div class="list-item">${esc(c.make)} ${esc(c.model)} ${c.year ?? ''} · لوحة: ${esc(c.plate_number ?? '—')} · لون: ${esc(c.color ?? '—')}</div>`
        )
        .join('') || '<div class="muted">لا سيارات</div>'}
      <h3>${ICONS.wrench} بيانات مقدم الخدمة</h3>
      ${
        prov
          ? `<div class="list-item">الورشة: ${esc(prov.workshop_name)} · ${esc(prov.address ?? '')}</div>
             <div class="list-item">${ICONS.pin} الموقع: ${esc(prov.latitude)}, ${esc(prov.longitude)} · تحديث: ${fmt(prov.location_updated_at)}</div>
             <div class="list-item">${prov.is_online ? '<span class="badge online">متصل</span>' : '<span class="badge offline">غير متصل</span>'} · نطاق الخدمة: ${esc(prov.support_scope)} · مركبة: ${prov.has_vehicle ? 'يوجد' : 'لا يوجد'}</div>`
          : '<div class="muted">—</div>'
      }
      <h3>${ICONS.clipboard} تخصصات</h3>
      <div>${(d.specializations ?? []).map((s: any) => esc(s.name_ar ?? s.id)).join('، ') || '<span class="muted">—</span>'}</div>`,
  });

  tabs.push({
    id: 'orders',
    label: 'طلبات',
    icon: ICONS.clipboard,
    html: `
      <h3>طلبات كمالك (آخر 20)</h3>
      ${(d.orders_as_owner ?? []).map(orderRow).join('') || '<div class="muted">لا طلبات</div>'}
      <h3>طلبات كمقدم خدمة (آخر 20)</h3>
      ${(d.orders_as_provider ?? []).map(orderRow).join('') || '<div class="muted">لا طلبات</div>'}`,
  });

  tabs.push({
    id: 'notifs',
    label: 'إشعارات',
    icon: ICONS.bell,
    html: notif
      ? `
      <div class="summary-row">
        ${Object.entries(notif.summary ?? {})
          .map(([k, v]) => `<div class="status-chip"><span>${esc(NOTIF_LABELS[k] ?? k)}</span><b>${esc(v ?? 0)}</b></div>`)
          .join('') || '<span class="muted">لا إشعارات إطلاقًا</span>'}
      </div>
      <h3>آخر 30 إشعار</h3>
      ${(notif.recent ?? []).map(notifRow).join('') || '<div class="muted">لا إشعارات</div>'}`
      : '<div class="muted">غير متاح</div>',
  });

  tabs.push({
    id: 'audit',
    label: 'تقييمات وسجل',
    icon: ICONS.shield,
    html: `
      <h3>${ICONS.star} تقييمات</h3>
      <div class="list-item">
        استلماها: <b>${esc(d.ratings_received?.avg ?? '—')}</b> من 5 (${esc(d.ratings_received?.count ?? 0)}) ·
        أرسلتها: <b>${esc(d.ratings_given?.avg ?? '—')}</b> من 5 (${esc(d.ratings_given?.count ?? 0)})
      </div>
      <h3>${ICONS.shield} عمليات الأدمن على المستخدم ده</h3>
      ${(d.audit_entries ?? [])
        .map(
          (a: any) =>
            `<div class="list-item"><span class="badge">${esc(a.action)}</span> ${fmt(a.created_at)} · ${esc(a.details ? JSON.stringify(a.details) : '')}</div>`
        )
        .join('') || '<div class="muted">لا عمليات مسجلة على المستخدم ده</div>'}`,
  });

  drawer.innerHTML = `
    <div class="drawer-head">
      <div>
        <h2>${esc(p.full_name ?? '—')}</h2>
        <div class="drawer-sub">
          ${p.role === 'provider' ? '<span class="badge provider">مقدم خدمة</span>' : '<span class="badge owner">مالك سيارة</span>'}
          <span dir="ltr" class="muted">${esc(p.phone_number ?? '')}</span>
        </div>
      </div>
      <button class="secondary icon-btn" id="drawer-close">${ICONS.x}</button>
    </div>
    <div class="drawer-tabs">
      ${tabs.map((t, i) => `<button class="drawer-tab ${i === 0 ? 'active' : ''}" data-tab="${t.id}">${t.icon}<span>${esc(t.label)}</span></button>`).join('')}
    </div>
    <div class="drawer-body" id="drawer-body"></div>`;

  const tabButtons = Array.from(drawer.querySelectorAll('.drawer-tab')) as HTMLButtonElement[];
  const body = drawer.querySelector('#drawer-body') as HTMLElement;
  const showTab = (id: string) => {
    tabButtons.forEach((b) => b.classList.toggle('active', b.dataset.tab === id));
    body.innerHTML = tabs.find((t) => t.id === id)!.html;
  };
  tabButtons.forEach((b) => (b.onclick = () => showTab(b.dataset.tab!)));
  showTab('basics');

  // ban / unban via delegated click (tab content is rebuilt on each switch)
  body.onclick = async (ev) => {
    const el = (ev.target as HTMLElement).closest('[data-action]') as HTMLElement | null;
    if (!el) return;
    const action = el.dataset.action;
    if (action === 'ban') {
      const reason = window.prompt('سبب حظر الحساب (5 حروف على الأقل، يُسجل بالاسم):');
      if (reason == null) return;
      if (reason.trim().length < 5) {
        return window.alert('السبب لازم 5 حروف على الأقل');
      }
      const durSel = drawer.querySelector('#ban-duration') as HTMLSelectElement | null;
      const daysNum = durSel && durSel.value ? Number(durSel.value) : null;
      const endsAt = daysNum
        ? new Date(Date.now() + daysNum * 24 * 60 * 60 * 1000).toISOString().slice(0, 10)
        : null;
      const msg =
        'تأكيد حظر الحساب؟\n\n' +
        (daysNum
          ? `• حظر مؤقت: ${daysNum} يوم (ينتهي تلقائيًا بتاريخ ${endsAt})\n`
          : '• حظر دائم (مش هيتفك لوحده)\n') +
        '• مش هيعرف يسجل دخول طالما الحظر شغال\n' +
        '• كل جلساته الحالية هتتقفل فورًا (تسجيل خروج إجباري)\n' +
        '• هيوصله إشعار (push + داخل التطبيق):\n'
        + '   „تم حظرك — سبب: ' + reason.trim() + '“';
      if (!window.confirm(msg)) return;
      try {
        await rpcSilent('admin_ban_user', {
          p_user_id: uid,
          p_reason: reason.trim(),
          p_ban_days: daysNum,
        });
        window.alert(
          daysNum
            ? `تم الحظر المؤقت (${daysNum} يوم — ينتهي ${endsAt}). الجلسات اتقفلت + الإشعار اتبعت + اتسجل.`
            : 'تم الحظر الدائم. الجلسات اتقفلت + الإشعار اتبعت + اتسجل في سجل الأدمن مع السبب.'
        );
        openDrawer(uid);
      } catch (e: any) {
        window.alert(e?.message ?? 'خطأ');
      }
    } else if (action === 'unban') {
      if (!window.confirm(
        'رفع الحظر عن الحساب؟\n\n' +
        '• هيعرف يسجل دخول عادي\n' +
        '• هيوصله إشعار „تم رفع الحظر — سجل دخول من جديد“'
      )) return;
      try {
        await rpcSilent('admin_unban_user', { p_user_id: uid });
        window.alert('تم رفع الحظر + الإشعار اتبعت + اتسجل في سجل الأدمن.');
        openDrawer(uid);
      } catch (e: any) {
        window.alert(e?.message ?? 'خطأ');
      }
    }
  };

  (drawer.querySelector('#drawer-close') as HTMLButtonElement).onclick = closeDrawer;
}

addEventListener('keydown', (ev) => {
  if (ev.key === 'Escape') closeDrawer();
});

// ---------------------------------------------------------------------------
// View: orders (5B board — filter by status / search / paginate, click → drawer).
// ---------------------------------------------------------------------------
const ordersState = { page: 1, pageSize: 25, status: '', search: '', total: 0, totalPages: 1 };
let currentOrdersRows: any[] = [];

function renderOrders(v: HTMLElement) {
  v.innerHTML = `
    <h1 class="view-title">${ICONS.clipboard} الطلبات</h1>
    <div class="panel">
      <div class="toolbar">
        <div class="searchbox">${ICONS.search}<input type="text" id="o-search" value="${esc(ordersState.search)}" placeholder="بحث بالإسم / الموبايل / الخدمة / العنوان…" /></div>
        <select id="o-status">
          <option value="" ${ordersState.status === '' ? 'selected' : ''}>كل الحالات</option>
          ${Object.entries(ORDER_STATUS)
            .map(([k, m]) => `<option value="${k}" ${ordersState.status === k ? 'selected' : ''}>${esc(m.label)}</option>`)
            .join('')}
        </select>
        <button id="o-apply">بحث</button>
      </div>
      <div class="table-wrap"><table>
        <thead><tr>
          <th>الخدمة</th><th>الحالة</th><th>المالك</th><th>مقدم الخدمة</th>
          <th>السعر</th><th>السيارة</th><th>العنوان</th><th>الأُنشئ</th>
        </tr></thead>
        <tbody id="o-rows"><tr><td class="muted">جارٍ التحميل…</td></tr></tbody>
      </table></div>
      <div class="pager">
        <button class="secondary" id="o-prev">${ICONS.chevronL}</button>
        <span class="info" id="o-pageinfo"></span>
        <button class="secondary" id="o-next">${ICONS.chevronR}</button>
      </div>
    </div>`;

  (v.querySelector('#o-apply') as HTMLButtonElement).onclick = () => {
    ordersState.search = (v.querySelector('#o-search') as HTMLInputElement).value.trim();
    ordersState.status = (v.querySelector('#o-status') as HTMLSelectElement).value;
    ordersState.page = 1;
    loadOrders(v);
  };
  (v.querySelector('#o-search') as HTMLInputElement).onkeydown = (ev) => {
    if ((ev as KeyboardEvent).key === 'Enter')
      (v.querySelector('#o-apply') as HTMLButtonElement).click();
  };
  (v.querySelector('#o-prev') as HTMLButtonElement).onclick = () => {
    if (ordersState.page > 1) {
      ordersState.page--;
      loadOrders(v);
    }
  };
  (v.querySelector('#o-next') as HTMLButtonElement).onclick = () => {
    if (ordersState.page < ordersState.totalPages) {
      ordersState.page++;
      loadOrders(v);
    }
  };

  loadOrders(v);
}

async function loadOrders(v: HTMLElement) {
  const rows = v.querySelector('#o-rows') as HTMLElement;
  rows.innerHTML = '<tr><td class="muted">جارٍ التحميل…</td></tr>';
  try {
    const data: any[] = await rpcSilent('admin_list_orders', {
      p_page: ordersState.page,
      p_page_size: ordersState.pageSize,
      p_status: ordersState.status || null,
      p_search: ordersState.search || null,
    });
    ordersState.total = Number(data[0]?.total_count ?? 0);
    ordersState.totalPages = Math.max(1, Math.ceil(ordersState.total / ordersState.pageSize));
    currentOrdersRows = data;

    if (!data.length) {
      rows.innerHTML = '<tr><td class="muted">لا نتائج</td></tr>';
    } else {
      rows.innerHTML = data
        .map((o, idx) => {
          const st = ORDER_STATUS[o.status] ?? { label: o.status, cls: '' };
          return `<tr data-oidx="${idx}">
            <td>${esc(o.service ?? '—')}</td>
            <td><span class="badge ${st.cls}">${esc(st.label)}</span></td>
            <td>${esc(o.owner_name ?? '—')}</td>
            <td>${esc(o.provider_name ?? '<span class="muted">لم يُعيَّن</span>')}</td>
            <td>${o.offered_price != null ? `<b>${esc(o.offered_price)}</b> ${esc(o.currency ?? '')}` : '<span class="muted">—</span>'}</td>
            <td class="small">${esc(o.car_title ?? '—')}</td>
            <td class="small muted">${esc(o.address_text ?? '—')}</td>
            <td class="small muted">${fmt(o.created_at)}</td>
          </tr>`;
        })
        .join('');
      rows.querySelectorAll('tr[data-oidx]').forEach((tr) => {
        (tr as HTMLElement).onclick = () =>
          openOrderDrawer(currentOrdersRows[Number((tr as HTMLElement).dataset.oidx)]);
      });
    }
    (v.querySelector('#o-pageinfo') as HTMLElement).textContent =
      `صفحة ${ordersState.page} من ${ordersState.totalPages} — إجمالي ${ordersState.total}`;
  } catch (e: any) {
    rows.innerHTML = `<tr><td class="muted">${esc(e?.message ?? 'خطأ')}</td></tr>`;
  }
}

function openOrderDrawer(o: any) {
  const overlay = document.getElementById('drawer-overlay') as HTMLElement;
  const drawer = document.getElementById('drawer') as HTMLElement;
  overlay.classList.remove('hidden');
  document.body.style.overflow = 'hidden';
  overlay.onclick = (ev) => {
    if (ev.target === overlay) closeDrawer();
  };

  const st = ORDER_STATUS[o.status] ?? { label: o.status, cls: '' };
  drawer.innerHTML = `
    <div class="drawer-head">
      <div>
        <h2>${esc(o.service ?? 'طلب')}</h2>
        <div class="drawer-sub">
          <span class="badge ${st.cls}">${esc(st.label)}</span>
          <code dir="ltr" class="tiny muted">${esc(String(o.id).slice(0, 8))}…</code>
        </div>
      </div>
      <button class="secondary icon-btn" id="drawer-close">${ICONS.x}</button>
    </div>
    <div class="drawer-tabs">
      <button class="drawer-tab active">${ICONS.clipboard}<span>تفاصيل الطلب</span></button>
    </div>
    <div class="drawer-body">
      <dl class="kv">
        <dt>السعر</dt><dd>${o.offered_price != null ? esc(o.offered_price) + ' ' + esc(o.currency ?? '') : '—'}</dd>
        <dt>المالك</dt><dd>${esc(o.owner_name ?? '—')}${o.owner_phone ? ' · <span dir="ltr">' + esc(o.owner_phone) + '</span>' : ''}</dd>
        <dt>مقدم الخدمة</dt><dd>${esc(o.provider_name ?? 'لم يُعيَّن')}</dd>
        <dt>السيارة</dt><dd>${esc(o.car_title ?? '—')}</dd>
        <dt>العنوان</dt><dd>${esc(o.address_text ?? '—')}</dd>
        <dt>مكانك معالجة متوقع (ETA)</dt><dd>${o.eta_minutes != null ? esc(o.eta_minutes) + ' دقيقة' : '—'}</dd>
        <dt>مشاركة رقم المستخدم</dt><dd>${o.share_phone ? 'مسموحة' : 'غير مسموحة'}</dd>
        <dt>مرفقات العميل / المقدم</dt><dd>${esc(o.attachments_count ?? 0)} / ${esc(o.provider_attachments_count ?? 0)}</dd>
        <dt>ملاحظات العميل</dt><dd>${esc(o.notes ?? '—')}</dd>
        <dt>ملاحظات المقدم</dt><dd>${esc(o.provider_notes ?? '—')}</dd>
        <dt>أُنشئ</dt><dd>${fmt(o.created_at)}</dd>
        <dt>آخر تحديث</dt><dd>${fmt(o.updated_at)}</dd>
      </dl>
    </div>`;

  (drawer.querySelector('#drawer-close') as HTMLButtonElement).onclick = closeDrawer;
}

// ---------------------------------------------------------------------------
// View: bans (history of ban/unban actions from admin audit log).
// ---------------------------------------------------------------------------
const bansState = { page: 1, pageSize: 25, total: 0, totalPages: 1 };
let currentBanRows: any[] = [];

function renderBans(v: HTMLElement) {
  v.innerHTML = `
    <h1 class="view-title">${ICONS.shield} سجل الحظر</h1>
    <div class="panel">
      <div class="sub">كل عمليات الحظر والرفع متسجلة تلقائيًا من قاعدة البيانات (المستخدم، السبب، المدة، الحالة الآن).</div>
      <div class="table-wrap"><table>
        <thead><tr>
          <th>الحدث</th><th>المستخدم</th><th>السبب</th><th>المدة</th>
          <th>ينتهي</th><th>الوقت</th><th>الآن</th>
        </tr></thead>
        <tbody id="b-rows"><tr><td class="muted">جارٍ التحميل…</td></tr></tbody>
      </table></div>
      <div class="pager">
        <button class="secondary" id="b-prev">${ICONS.chevronL}</button>
        <span class="info" id="b-pageinfo"></span>
        <button class="secondary" id="b-next">${ICONS.chevronR}</button>
        <button class="secondary" id="b-refresh">${ICONS.refresh} تحديث</button>
      </div>
    </div>`;

  (v.querySelector('#b-prev') as HTMLButtonElement).onclick = () => {
    if (bansState.page > 1) { bansState.page--; loadBans(v); }
  };
  (v.querySelector('#b-next') as HTMLButtonElement).onclick = () => {
    if (bansState.page < bansState.totalPages) { bansState.page++; loadBans(v); }
  };
  (v.querySelector('#b-refresh') as HTMLButtonElement).onclick = () => loadBans(v);

  // رفع الحظر من داخل السجل مباشرة
  v.querySelector('#b-rows')!.addEventListener('click', async (ev) => {
    const btn = (ev.target as HTMLElement).closest('[data-unban]') as HTMLElement | null;
    if (!btn) return;
    const uid = btn.dataset.unban!;
    if (!window.confirm('رفع الحظر عن الحساب؟')) return;
    try {
      await rpcSilent('admin_unban_user', { p_user_id: uid });
      window.alert('تم رفع الحظر + الإشعار اتبعت + اتسجل في سجل الأدمن.');
      loadBans(v);
    } catch (e: any) {
      window.alert(e?.message ?? 'خطأ');
    }
  });

  loadBans(v);
}

async function loadBans(v: HTMLElement) {
  const rows = v.querySelector('#b-rows') as HTMLElement;
  rows.innerHTML = '<tr><td class="muted">جارٍ التحميل…</td></tr>';
  try {
    const data: any[] = await rpcSilent('admin_ban_history', {
      p_page: bansState.page,
      p_page_size: bansState.pageSize,
    });
    bansState.total = Number(data[0]?.total_count ?? 0);
    bansState.totalPages = Math.max(1, Math.ceil(bansState.total / bansState.pageSize));
    currentBanRows = data;
    if (!data.length) {
      rows.innerHTML = '<tr><td class="muted">لا عمليات بعد</td></tr>';
    } else {
      rows.innerHTML = data
        .map((b) => {
          const isBan = b.action === 'ban_user';
          return `<tr>
            <td><span class="badge ${isBan ? 'st-rejected' : 'st-completed'}">${isBan ? 'حظر' : 'رفع الحظر'}</span></td>
            <td>${esc(b.target_name ?? '—')}<div class="tiny muted" dir="ltr">${esc(b.target_email ?? '')}</div></td>
            <td class="small">${esc(b.reason ?? '—')}</td>
            <td>${b.ban_days != null ? esc(b.ban_days) + ' يوم' : (isBan ? 'دائم' : '—')}</td>
            <td class="small muted">${isBan && b.banned_until ? fmt(b.banned_until) : '—'}</td>
            <td class="small muted">${fmt(b.created_at)}</td>
            <td>${
              b.currently_banned
                ? `<span class="badge st-rejected">محظور حاليًا</span>
                   <button class="secondary tiny-btn" data-unban="${esc(String(b.target_id))}">رفع</button>`
                : (isBan ? '<span class="muted small">مرتفع (انتهى)</span>' : '<span class="muted small">—</span>')
            }</td>
          </tr>`;
        })
        .join('');
    }
    (v.querySelector('#b-pageinfo') as HTMLElement).textContent =
      `صفحة ${bansState.page} من ${bansState.totalPages} — إجمالي ${bansState.total}`;
  } catch (e: any) {
    rows.innerHTML = `<tr><td class="muted">${esc(e?.message ?? 'خطأ')}</td></tr>`;
  }
}

// ---------------------------------------------------------------------------
// View: messages (targeted custom broadcast composer).
// ---------------------------------------------------------------------------
type PickerUser = { id: string; name: string; phone: string; role: string };
const selectedUsers = new Map<string, PickerUser>();

function userChipsHtml() {
  return Array.from(selectedUsers.values())
    .map(
      (u) =>
        `<span class="chip">${esc(u.name || u.phone)}<button data-unpick="${esc(u.id)}" title="إزالة">${ICONS.x}</button></span>`
    )
    .join('');
}

async function renderMessages(v: HTMLElement) {
  v.innerHTML = `
    <h1 class="view-title">${ICONS.bell} الرسائل والإشعارات</h1>
    <div class="panel">
      <h2>${ICONS.bell} رسالة مخصصة</h2>
      <div class="sub">
        نفس نظام إشعارات التطبيق الحالي (type=broadcast): الرسالة تتسجل في شاشة
        الإشعارات عند كل مستخدم وبيوصل FCM push فوري لكل جهاز محدد. المستخدمون
        المنضمون من غير profile (زي حساب الأدمن) بيتم تخطيهم تلقائيًا.
      </div>
      <div class="msg info hidden" id="m-msg"></div>

      <div class="field">
        <label>المستلمون</label>
        <select id="rcpt-mode">
          <option value="all">الجميع (كل المستخدمين)</option>
          <option value="car_owner">أصحاب السيارات فقط</option>
          <option value="provider">مقدمو الخدمة فقط</option>
          <option value="custom">مستخدمون محددون (اختيار يدوي)</option>
        </select>
      </div>

      <div id="picker" class="hidden">
        <div class="toolbar">
          <div class="searchbox">${ICONS.search}<input type="text" id="pk-search" placeholder="بحث بالإسم / الموبايل / الإيميل…" /></div>
          <button class="secondary" id="pk-search-btn">بحث</button>
        </div>
        <div id="pk-results" class="picker-list"><span class="muted">ابحث واختار…</span></div>
        <div id="pk-selected" class="chips"></div>
      </div>

      <div class="field"><label>العنوان (حتى 100 حرف)</label><input type="text" id="m-title" maxlength="100" /></div>
      <div class="field"><label>النص (حتى 400 حرف)</label><textarea id="m-body" maxlength="400"></textarea></div>
      <div class="field">
        <label>وجهة الضغط (اختياري): "home" = شاشة الرئيسية، أو رابط http/https خارجي، فاضي = صفحة الإشعارات</label>
        <input type="text" id="m-link" dir="ltr" maxlength="500" />
      </div>
      <div class="btn-row"><button id="m-send">${ICONS.bell} إرسال الرسالة</button></div>
    </div>`;

  const msgBox = v.querySelector('#m-msg') as HTMLElement;
  const setMsg = (text: string, kind: 'err' | 'info' = 'err') => {
    msgBox.textContent = text;
    msgBox.className = `msg ${kind} show`;
    setTimeout(() => msgBox.classList.add('hidden'), 8000);
  };

  const modeSel = v.querySelector('#rcpt-mode') as HTMLSelectElement;
  const picker = v.querySelector('#picker') as HTMLElement;

  modeSel.onchange = () => {
    if (modeSel.value === 'custom') picker.classList.remove('hidden');
    else picker.classList.add('hidden');
  };

  // ---- manual picker --------------------------------------------------------
  const searchBtn = v.querySelector('#pk-search-btn') as HTMLButtonElement;
  const searchInput = v.querySelector('#pk-search') as HTMLInputElement;
  const resultsBox = v.querySelector('#pk-results') as HTMLElement;
  const chipsBox = v.querySelector('#pk-selected') as HTMLElement;

  const renderChips = () => {
    chipsBox.innerHTML = userChipsHtml();
  };

  const loadPicker = async () => {
    const q = searchInput.value.trim();
    resultsBox.innerHTML = '<span class="muted">جارٍ البحث…</span>';
    try {
      const rows: any[] = await rpcSilent('admin_list_users', {
        p_page: 1, p_page_size: 20, p_search: q || null, p_role: null,
      });
      if (!rows.length) {
        resultsBox.innerHTML = '<span class="muted">لا نتائج</span>';
        return;
      }
      resultsBox.innerHTML = rows
        .map(
          (u) => `<label class="picker-item">
            <input type="checkbox" data-pu="${esc(u.user_id)}" data-name="${esc(u.full_name ?? '')}" data-phone="${esc(u.phone_number ?? '')}" data-role="${esc(u.role ?? '')}" ${selectedUsers.has(u.user_id) ? 'checked' : ''} />
            <span>${esc(u.full_name ?? '—')}</span>
            <span dir="ltr" class="muted small">${esc(u.phone_number ?? '')}</span>
            <span class="badge ${u.role === 'provider' ? 'provider' : 'owner'}">${esc(ROLE_LABEL[u.role] ?? u.role)}</span>
            ${u.banned ? '<span class="badge st-rejected">محظور</span>' : ''}
          </label>`
        )
        .join('');
    } catch (e: any) {
      resultsBox.innerHTML = `<span class="muted">${esc(e?.message ?? 'خطأ')}</span>`;
    }
  };

  searchBtn.onclick = loadPicker;
  searchInput.onkeydown = (ev) => {
    if ((ev as KeyboardEvent).key === 'Enter') loadPicker();
  };

  resultsBox.onchange = (ev) => {
    const input = ev.target as HTMLInputElement;
    if (!input?.dataset?.pu) return;
    if (input.checked) {
      selectedUsers.set(input.dataset.pu, {
        id: input.dataset.pu,
        name: input.dataset.name ?? '',
        phone: input.dataset.phone ?? '',
        role: input.dataset.role ?? '',
      });
    } else {
      selectedUsers.delete(input.dataset.pu);
    }
    renderChips();
  };

  chipsBox.onclick = (ev) => {
    const btn = (ev.target as HTMLElement).closest('[data-unpick]') as HTMLElement | null;
    if (!btn) return;
    selectedUsers.delete(btn.dataset.unpick!);
    renderChips();
  };

  // ---- send -----------------------------------------------------------------
  const sendBtn = v.querySelector('#m-send') as HTMLButtonElement;
  sendBtn.onclick = async () => {
    sendBtn.disabled = true;
    try {
      // 1) resolve recipients
      let ids: string[] = [];
      if (modeSel.value === 'custom') {
        ids = Array.from(selectedUsers.keys());
        if (!ids.length) throw new Error('اختار مستخدمًا واحدًا على الأقل');
      } else {
        const rows: any[] = await rpcSilent('admin_export_users', {
          p_search: null,
          p_role: modeSel.value === 'all' ? null : modeSel.value,
        });
        ids = rows.map((r) => r.user_id).filter(Boolean);
        if (!ids.length) throw new Error('لا مستخدمين في الفئة المختارة');
      }

      // 2) confirm summary
      const title = (v.querySelector('#m-title') as HTMLInputElement).value.trim();
      const bodyText = (v.querySelector('#m-body') as HTMLTextAreaElement).value.trim();
      if (!window.confirm(
        `تأكيد الإرسال؟\nالمستلمون: ${ids.length}\nالعنوان: ${title}\nالنص: ${bodyText}`
      )) {
        sendBtn.disabled = false;
        return;
      }

      const link = (v.querySelector('#m-link') as HTMLInputElement).value.trim();
      const inserted: number = await rpcSilent('admin_send_targeted_messages', {
        p_user_ids: ids,
        p_title: title,
        p_body: bodyText,
        p_deep_link: link || null,
      });
      window.alert(`تم إرسال الرسالة لـ ${inserted} مستخدم (تخطي غير المنضمين للفئة). العملية اتسجلت في سجل الأدمن.`);
      setMsg(`تم إرسال الرسالة لـ ${inserted} مستخدم.`, 'info');
    } catch (e: any) {
      setMsg(e?.message ?? 'خطأ في الإرسال');
    }
    sendBtn.disabled = false;
  };
}

// ---------------------------------------------------------------------------
// View: exports.
// ---------------------------------------------------------------------------
function renderExports(v: HTMLElement) {
  v.innerHTML = `
    <h1 class="view-title">${ICONS.download} التصدير</h1>
    <div class="panel">
      <h2>${ICONS.users} المستخدمون</h2>
      <div class="sub">تصدير كل الحسابات (أو الفلترة الحالية لصفحة المستخدمين لو فعّلت الخيار تحت). كل عملية تصدير بتتسجل في سجل المؤسسة.</div>
      <div class="row-check">
        <label><input type="checkbox" id="use-filters" /> استخدم فلترة المستخدمين الحالية (بحث/نوع)</label>
        <div class="muted small" id="filters-hint"></div>
      </div>
      <div class="btn-row">
        <button id="exp-csv">${ICONS.download} تصدير CSV</button>
        <button class="secondary" id="exp-json">${ICONS.download} تصدير JSON</button>
      </div>
    </div>
    <div class="panel">
      <h2>${ICONS.clipboard} الطلبات</h2>
      <div class="sub">تصدير الطلبات (بدون فلترة أو حسب فلترة صفحة الطلبات الحالية). كل تصدير متسجل في سجل المؤسسة.</div>
      <div class="row-check">
        <label><input type="checkbox" id="use-o-filters" /> استخدم فلترة الطلبات الحالية (حالة/بحث)</label>
        <div class="muted small" id="o-filters-hint"></div>
      </div>
      <div class="btn-row">
        <button id="o-exp-csv">${ICONS.download} تصدير الطلبات CSV</button>
        <button class="secondary" id="o-exp-json">${ICONS.download} تصدير الطلبات JSON</button>
      </div>
    </div>`;

  const hint = v.querySelector('#filters-hint') as HTMLElement;
  hint.textContent = listState.search
    ? `الفلاتر الحالية: بحث="${listState.search}"${listState.role ? ' · نوع=' + (ROLE_LABEL[listState.role] ?? listState.role) : ''}`
    : 'الفلاتر الحالية: بدون فلترة (الكل)';

  (v.querySelector('#exp-csv') as HTMLButtonElement).onclick = () =>
    doExport(v, 'csv');
  (v.querySelector('#exp-json') as HTMLButtonElement).onclick = () =>
    doExport(v, 'json');

  (v.querySelector('#use-filters') as HTMLInputElement).onchange = () => {
    hint.textContent = (v.querySelector('#use-filters') as HTMLInputElement).checked
      ? listState.search
        ? `الفلاتر الحالية: بحث="${listState.search}"${listState.role ? ' · نوع=' + (ROLE_LABEL[listState.role] ?? listState.role) : ''}`
        : 'الفلاتر الحالية: بدون فلترة (الكل)'
      : 'بدون فلترة (الكل)';
  };

  // ---- orders export ---------------------------------------------------------
  const oHint = v.querySelector('#o-filters-hint') as HTMLElement;
  const setOHint = () => {
    oHint.textContent = (v.querySelector('#use-o-filters') as HTMLInputElement).checked
      ? `الفلاتر الحالية: ${(ordersState.status ? ORDER_STATUS[ordersState.status]?.label + ' · ' : '')}${(ordersState.search ? 'بحث="' + ordersState.search + '"' : (ordersState.status ? '' : 'الكل'))}`
      : 'بدون فلترة (الكل)';
  };
  setOHint();
  (v.querySelector('#use-o-filters') as HTMLInputElement).onchange = setOHint as any;

  (v.querySelector('#o-exp-csv') as HTMLButtonElement).onclick = () =>
    doOrderExport(v, 'csv');
  (v.querySelector('#o-exp-json') as HTMLButtonElement).onclick = () =>
    doOrderExport(v, 'json');
}

async function doOrderExport(v: HTMLElement, format: 'csv' | 'json') {
  const csvBtn = v.querySelector('#o-exp-csv') as HTMLButtonElement;
  const jsonBtn = v.querySelector('#o-exp-json') as HTMLButtonElement;
  const btn = format === 'csv' ? csvBtn : jsonBtn;
  const orig = btn.textContent;
  btn.disabled = true;
  btn.textContent = 'جارٍ التصدير…';
  try {
    const useFilters = (v.querySelector('#use-o-filters') as HTMLInputElement).checked;
    const rows: any[] = await rpcSilent('admin_export_orders', {
      p_status: useFilters ? ordersState.status || null : null,
      p_search: useFilters ? ordersState.search || null : null,
    });
    const headers = [
      'id', 'service', 'status', 'offered_price', 'currency', 'owner_name',
      'provider_name', 'owner_phone', 'car_title', 'address_text', 'eta_minutes',
      'notes', 'provider_notes', 'attachments_count', 'provider_attachments_count',
      'share_phone', 'created_at', 'updated_at',
    ];
    if (format === 'csv') {
      const csv = [
        headers.join(','),
        ...rows.map((r) =>
          headers
            .map((h) => {
              let val = r[h] ?? '';
              if (val instanceof Date) val = val.toISOString();
              const s = String(val);
              return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
            })
            .join(',')
        ),
      ].join('\n');
      downloadBlob(csv, 'text/csv;charset=utf-8', 'csv', rows.length, 'mahwar_orders');
    } else {
      downloadBlob(JSON.stringify(rows, null, 2), 'application/json', 'json', rows.length, 'mahwar_orders');
    }
  } catch (e: any) {
    window.alert(e?.message ?? 'خطأ في التصدير');
  }
  btn.disabled = false;
  btn.textContent = orig;
}

async function fetchExportRows(useFilters: boolean): Promise<any[]> {
  return rpcSilent('admin_export_users', {
    p_search: useFilters ? listState.search || null : null,
    p_role: useFilters ? listState.role || null : null,
  });
}

function downloadBlob(content: string, mime: string, ext: string, count: number, prefix = 'mahwar_users') {
  const blob = new Blob(['\ufeff', content], { type: mime });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `${prefix}_${new Date().toISOString().slice(0, 10)}.${ext}`;
  a.click();
  URL.revokeObjectURL(a.href);
  window.alert(`تم تصدير ${count} صف. العملية متسجلة في سجل المؤسسة.`);
}

async function doExport(
  v: HTMLElement,
  format: 'csv' | 'json' | null,
  resetLock = false
) {
  const csvBtn = v.querySelector('#exp-csv') as HTMLButtonElement | null;
  const jsonBtn = v.querySelector('#exp-json') as HTMLButtonElement | null;
  if (resetLock || !format) return;
  const btn = format === 'csv' ? csvBtn! : jsonBtn!;
  const orig = btn.textContent;
  btn.disabled = true;
  btn.textContent = 'جارٍ التصدير…';
  try {
    const useFilters = (v.querySelector('#use-filters') as HTMLInputElement).checked;
    const rows = await fetchExportRows(useFilters);

    if (format === 'csv') {
    const headers = [
      'user_id', 'full_name', 'phone_number', 'email', 'national_id', 'role', 'workshop_name',
      'is_online', 'phone_verified', 'banned', 'orders_as_owner', 'orders_as_provider', 'created_at',
    ];
      const csv = [
        headers.join(','),
        ...rows.map((r) =>
          headers
            .map((h) => {
              let val = r[h] ?? '';
              if (val instanceof Date) val = val.toISOString();
              const s = String(val);
              return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
            })
            .join(',')
        ),
      ].join('\n');
      downloadBlob(csv, 'text/csv;charset=utf-8', 'csv', rows.length);
    } else {
      downloadBlob(JSON.stringify(rows, null, 2), 'application/json', 'json', rows.length);
    }
  } catch (e: any) {
    window.alert(e?.message ?? 'خطأ في التصدير');
  }
  btn.disabled = false;
  btn.textContent = orig;
}

boot();
