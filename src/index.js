var __defProp = Object.defineProperty;
var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });
var __publicField = (obj, key, value) => {
  __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);
  return value;
};

// node_modules/unenv/dist/runtime/_internal/utils.mjs
function createNotImplementedError(name) {
  return new Error(`[unenv] ${name} is not implemented yet!`);
}
__name(createNotImplementedError, "createNotImplementedError");
function notImplemented(name) {
  const fn = /* @__PURE__ */ __name(() => {
    throw createNotImplementedError(name);
  }, "fn");
  return Object.assign(fn, { __unenv__: true });
}
__name(notImplemented, "notImplemented");
function notImplementedClass(name) {
  return class {
    __unenv__ = true;
    constructor() {
      throw new Error(`[unenv] ${name} is not implemented yet!`);
    }
  };
}
__name(notImplementedClass, "notImplementedClass");

// node_modules/unenv/dist/runtime/node/internal/perf_hooks/performance.mjs
var _timeOrigin = globalThis.performance?.timeOrigin ?? Date.now();
var _performanceNow = globalThis.performance?.now ? globalThis.performance.now.bind(globalThis.performance) : () => Date.now() - _timeOrigin;
var nodeTiming = {
  name: "node",
  entryType: "node",
  startTime: 0,
  duration: 0,
  nodeStart: 0,
  v8Start: 0,
  bootstrapComplete: 0,
  environment: 0,
  loopStart: 0,
  loopExit: 0,
  idleTime: 0,
  uvMetricsInfo: {
    loopCount: 0,
    events: 0,
    eventsWaiting: 0
  },
  detail: void 0,
  toJSON() {
    return this;
  }
};
var PerformanceEntry = class {
  __unenv__ = true;
  detail;
  entryType = "event";
  name;
  startTime;
  constructor(name, options) {
    this.name = name;
    this.startTime = options?.startTime || _performanceNow();
    this.detail = options?.detail;
  }
  get duration() {
    return _performanceNow() - this.startTime;
  }
  toJSON() {
    return {
      name: this.name,
      entryType: this.entryType,
      startTime: this.startTime,
      duration: this.duration,
      detail: this.detail
    };
  }
};
__name(PerformanceEntry, "PerformanceEntry");
var PerformanceMark = /* @__PURE__ */ __name(class PerformanceMark2 extends PerformanceEntry {
  entryType = "mark";
  constructor() {
    super(...arguments);
  }
  get duration() {
    return 0;
  }
}, "PerformanceMark");
var PerformanceMeasure = class extends PerformanceEntry {
  entryType = "measure";
};
__name(PerformanceMeasure, "PerformanceMeasure");
var PerformanceResourceTiming = class extends PerformanceEntry {
  entryType = "resource";
  serverTiming = [];
  connectEnd = 0;
  connectStart = 0;
  decodedBodySize = 0;
  domainLookupEnd = 0;
  domainLookupStart = 0;
  encodedBodySize = 0;
  fetchStart = 0;
  initiatorType = "";
  name = "";
  nextHopProtocol = "";
  redirectEnd = 0;
  redirectStart = 0;
  requestStart = 0;
  responseEnd = 0;
  responseStart = 0;
  secureConnectionStart = 0;
  startTime = 0;
  transferSize = 0;
  workerStart = 0;
  responseStatus = 0;
};
__name(PerformanceResourceTiming, "PerformanceResourceTiming");
var PerformanceObserverEntryList = class {
  __unenv__ = true;
  getEntries() {
    return [];
  }
  getEntriesByName(_name, _type) {
    return [];
  }
  getEntriesByType(type) {
    return [];
  }
};
__name(PerformanceObserverEntryList, "PerformanceObserverEntryList");
var Performance = class {
  __unenv__ = true;
  timeOrigin = _timeOrigin;
  eventCounts = /* @__PURE__ */ new Map();
  _entries = [];
  _resourceTimingBufferSize = 0;
  navigation = void 0;
  timing = void 0;
  timerify(_fn, _options) {
    throw createNotImplementedError("Performance.timerify");
  }
  get nodeTiming() {
    return nodeTiming;
  }
  eventLoopUtilization() {
    return {};
  }
  markResourceTiming() {
    return new PerformanceResourceTiming("");
  }
  onresourcetimingbufferfull = null;
  now() {
    if (this.timeOrigin === _timeOrigin) {
      return _performanceNow();
    }
    return Date.now() - this.timeOrigin;
  }
  clearMarks(markName) {
    this._entries = markName ? this._entries.filter((e) => e.name !== markName) : this._entries.filter((e) => e.entryType !== "mark");
  }
  clearMeasures(measureName) {
    this._entries = measureName ? this._entries.filter((e) => e.name !== measureName) : this._entries.filter((e) => e.entryType !== "measure");
  }
  clearResourceTimings() {
    this._entries = this._entries.filter((e) => e.entryType !== "resource" || e.entryType !== "navigation");
  }
  getEntries() {
    return this._entries;
  }
  getEntriesByName(name, type) {
    return this._entries.filter((e) => e.name === name && (!type || e.entryType === type));
  }
  getEntriesByType(type) {
    return this._entries.filter((e) => e.entryType === type);
  }
  mark(name, options) {
    const entry = new PerformanceMark(name, options);
    this._entries.push(entry);
    return entry;
  }
  measure(measureName, startOrMeasureOptions, endMark) {
    let start;
    let end;
    if (typeof startOrMeasureOptions === "string") {
      start = this.getEntriesByName(startOrMeasureOptions, "mark")[0]?.startTime;
      end = this.getEntriesByName(endMark, "mark")[0]?.startTime;
    } else {
      start = Number.parseFloat(startOrMeasureOptions?.start) || this.now();
      end = Number.parseFloat(startOrMeasureOptions?.end) || this.now();
    }
    const entry = new PerformanceMeasure(measureName, {
      startTime: start,
      detail: {
        start,
        end
      }
    });
    this._entries.push(entry);
    return entry;
  }
  setResourceTimingBufferSize(maxSize) {
    this._resourceTimingBufferSize = maxSize;
  }
  addEventListener(type, listener, options) {
    throw createNotImplementedError("Performance.addEventListener");
  }
  removeEventListener(type, listener, options) {
    throw createNotImplementedError("Performance.removeEventListener");
  }
  dispatchEvent(event) {
    throw createNotImplementedError("Performance.dispatchEvent");
  }
  toJSON() {
    return this;
  }
};
__name(Performance, "Performance");
var PerformanceObserver = class {
  __unenv__ = true;
  _callback = null;
  constructor(callback) {
    this._callback = callback;
  }
  takeRecords() {
    return [];
  }
  disconnect() {
    throw createNotImplementedError("PerformanceObserver.disconnect");
  }
  observe(options) {
    throw createNotImplementedError("PerformanceObserver.observe");
  }
  bind(fn) {
    return fn;
  }
  runInAsyncScope(fn, thisArg, ...args) {
    return fn.call(thisArg, ...args);
  }
  asyncId() {
    return 0;
  }
  triggerAsyncId() {
    return 0;
  }
  emitDestroy() {
    return this;
  }
};
__name(PerformanceObserver, "PerformanceObserver");
__publicField(PerformanceObserver, "supportedEntryTypes", []);
var performance = globalThis.performance && "addEventListener" in globalThis.performance ? globalThis.performance : new Performance();

// node_modules/@cloudflare/unenv-preset/dist/runtime/polyfill/performance.mjs
globalThis.performance = performance;
globalThis.Performance = Performance;
globalThis.PerformanceEntry = PerformanceEntry;
globalThis.PerformanceMark = PerformanceMark;
globalThis.PerformanceMeasure = PerformanceMeasure;
globalThis.PerformanceObserver = PerformanceObserver;
globalThis.PerformanceObserverEntryList = PerformanceObserverEntryList;
globalThis.PerformanceResourceTiming = PerformanceResourceTiming;

// node_modules/unenv/dist/runtime/node/console.mjs
import { Writable } from "node:stream";

// node_modules/unenv/dist/runtime/mock/noop.mjs
var noop_default = Object.assign(() => {
}, { __unenv__: true });

// node_modules/unenv/dist/runtime/node/console.mjs
var _console = globalThis.console;
var _ignoreErrors = true;
var _stderr = new Writable();
var _stdout = new Writable();
var log = _console?.log ?? noop_default;
var info = _console?.info ?? log;
var trace = _console?.trace ?? info;
var debug = _console?.debug ?? log;
var table = _console?.table ?? log;
var error = _console?.error ?? log;
var warn = _console?.warn ?? error;
var createTask = _console?.createTask ?? /* @__PURE__ */ notImplemented("console.createTask");
var clear = _console?.clear ?? noop_default;
var count = _console?.count ?? noop_default;
var countReset = _console?.countReset ?? noop_default;
var dir = _console?.dir ?? noop_default;
var dirxml = _console?.dirxml ?? noop_default;
var group = _console?.group ?? noop_default;
var groupEnd = _console?.groupEnd ?? noop_default;
var groupCollapsed = _console?.groupCollapsed ?? noop_default;
var profile = _console?.profile ?? noop_default;
var profileEnd = _console?.profileEnd ?? noop_default;
var time = _console?.time ?? noop_default;
var timeEnd = _console?.timeEnd ?? noop_default;
var timeLog = _console?.timeLog ?? noop_default;
var timeStamp = _console?.timeStamp ?? noop_default;
var Console = _console?.Console ?? /* @__PURE__ */ notImplementedClass("console.Console");
var _times = /* @__PURE__ */ new Map();
var _stdoutErrorHandler = noop_default;
var _stderrErrorHandler = noop_default;

// node_modules/@cloudflare/unenv-preset/dist/runtime/node/console.mjs
var workerdConsole = globalThis["console"];
var {
  assert,
  clear: clear2,
  // @ts-expect-error undocumented public API
  context,
  count: count2,
  countReset: countReset2,
  // @ts-expect-error undocumented public API
  createTask: createTask2,
  debug: debug2,
  dir: dir2,
  dirxml: dirxml2,
  error: error2,
  group: group2,
  groupCollapsed: groupCollapsed2,
  groupEnd: groupEnd2,
  info: info2,
  log: log2,
  profile: profile2,
  profileEnd: profileEnd2,
  table: table2,
  time: time2,
  timeEnd: timeEnd2,
  timeLog: timeLog2,
  timeStamp: timeStamp2,
  trace: trace2,
  warn: warn2
} = workerdConsole;
Object.assign(workerdConsole, {
  Console,
  _ignoreErrors,
  _stderr,
  _stderrErrorHandler,
  _stdout,
  _stdoutErrorHandler,
  _times
});
var console_default = workerdConsole;

// node_modules/wrangler/_virtual_unenv_global_polyfill-@cloudflare-unenv-preset-node-console
globalThis.console = console_default;

// node_modules/unenv/dist/runtime/node/internal/process/hrtime.mjs
var hrtime = /* @__PURE__ */ Object.assign(/* @__PURE__ */ __name(function hrtime2(startTime) {
  const now = Date.now();
  const seconds = Math.trunc(now / 1e3);
  const nanos = now % 1e3 * 1e6;
  if (startTime) {
    let diffSeconds = seconds - startTime[0];
    let diffNanos = nanos - startTime[0];
    if (diffNanos < 0) {
      diffSeconds = diffSeconds - 1;
      diffNanos = 1e9 + diffNanos;
    }
    return [diffSeconds, diffNanos];
  }
  return [seconds, nanos];
}, "hrtime"), { bigint: /* @__PURE__ */ __name(function bigint() {
  return BigInt(Date.now() * 1e6);
}, "bigint") });

// node_modules/unenv/dist/runtime/node/internal/process/process.mjs
import { EventEmitter } from "node:events";

// node_modules/unenv/dist/runtime/node/internal/tty/read-stream.mjs
import { Socket } from "node:net";
var ReadStream = class extends Socket {
  fd;
  constructor(fd) {
    super();
    this.fd = fd;
  }
  isRaw = false;
  setRawMode(mode) {
    this.isRaw = mode;
    return this;
  }
  isTTY = false;
};
__name(ReadStream, "ReadStream");

// node_modules/unenv/dist/runtime/node/internal/tty/write-stream.mjs
import { Socket as Socket2 } from "node:net";
var WriteStream = class extends Socket2 {
  fd;
  constructor(fd) {
    super();
    this.fd = fd;
  }
  clearLine(dir3, callback) {
    callback && callback();
    return false;
  }
  clearScreenDown(callback) {
    callback && callback();
    return false;
  }
  cursorTo(x, y, callback) {
    callback && typeof callback === "function" && callback();
    return false;
  }
  moveCursor(dx, dy, callback) {
    callback && callback();
    return false;
  }
  getColorDepth(env2) {
    return 1;
  }
  hasColors(count3, env2) {
    return false;
  }
  getWindowSize() {
    return [this.columns, this.rows];
  }
  columns = 80;
  rows = 24;
  isTTY = false;
};
__name(WriteStream, "WriteStream");

// node_modules/unenv/dist/runtime/node/internal/process/process.mjs
var Process = class extends EventEmitter {
  env;
  hrtime;
  nextTick;
  constructor(impl) {
    super();
    this.env = impl.env;
    this.hrtime = impl.hrtime;
    this.nextTick = impl.nextTick;
    for (const prop of [...Object.getOwnPropertyNames(Process.prototype), ...Object.getOwnPropertyNames(EventEmitter.prototype)]) {
      const value = this[prop];
      if (typeof value === "function") {
        this[prop] = value.bind(this);
      }
    }
  }
  emitWarning(warning, type, code) {
    console.warn(`${code ? `[${code}] ` : ""}${type ? `${type}: ` : ""}${warning}`);
  }
  emit(...args) {
    return super.emit(...args);
  }
  listeners(eventName) {
    return super.listeners(eventName);
  }
  #stdin;
  #stdout;
  #stderr;
  get stdin() {
    return this.#stdin ??= new ReadStream(0);
  }
  get stdout() {
    return this.#stdout ??= new WriteStream(1);
  }
  get stderr() {
    return this.#stderr ??= new WriteStream(2);
  }
  #cwd = "/";
  chdir(cwd2) {
    this.#cwd = cwd2;
  }
  cwd() {
    return this.#cwd;
  }
  arch = "";
  platform = "";
  argv = [];
  argv0 = "";
  execArgv = [];
  execPath = "";
  title = "";
  pid = 200;
  ppid = 100;
  get version() {
    return "";
  }
  get versions() {
    return {};
  }
  get allowedNodeEnvironmentFlags() {
    return /* @__PURE__ */ new Set();
  }
  get sourceMapsEnabled() {
    return false;
  }
  get debugPort() {
    return 0;
  }
  get throwDeprecation() {
    return false;
  }
  get traceDeprecation() {
    return false;
  }
  get features() {
    return {};
  }
  get release() {
    return {};
  }
  get connected() {
    return false;
  }
  get config() {
    return {};
  }
  get moduleLoadList() {
    return [];
  }
  constrainedMemory() {
    return 0;
  }
  availableMemory() {
    return 0;
  }
  uptime() {
    return 0;
  }
  resourceUsage() {
    return {};
  }
  ref() {
  }
  unref() {
  }
  umask() {
    throw createNotImplementedError("process.umask");
  }
  getBuiltinModule() {
    return void 0;
  }
  getActiveResourcesInfo() {
    throw createNotImplementedError("process.getActiveResourcesInfo");
  }
  exit() {
    throw createNotImplementedError("process.exit");
  }
  reallyExit() {
    throw createNotImplementedError("process.reallyExit");
  }
  kill() {
    throw createNotImplementedError("process.kill");
  }
  abort() {
    throw createNotImplementedError("process.abort");
  }
  dlopen() {
    throw createNotImplementedError("process.dlopen");
  }
  setSourceMapsEnabled() {
    throw createNotImplementedError("process.setSourceMapsEnabled");
  }
  loadEnvFile() {
    throw createNotImplementedError("process.loadEnvFile");
  }
  disconnect() {
    throw createNotImplementedError("process.disconnect");
  }
  cpuUsage() {
    throw createNotImplementedError("process.cpuUsage");
  }
  setUncaughtExceptionCaptureCallback() {
    throw createNotImplementedError("process.setUncaughtExceptionCaptureCallback");
  }
  hasUncaughtExceptionCaptureCallback() {
    throw createNotImplementedError("process.hasUncaughtExceptionCaptureCallback");
  }
  initgroups() {
    throw createNotImplementedError("process.initgroups");
  }
  openStdin() {
    throw createNotImplementedError("process.openStdin");
  }
  assert() {
    throw createNotImplementedError("process.assert");
  }
  binding() {
    throw createNotImplementedError("process.binding");
  }
  permission = { has: /* @__PURE__ */ notImplemented("process.permission.has") };
  report = {
    directory: "",
    filename: "",
    signal: "SIGUSR2",
    compact: false,
    reportOnFatalError: false,
    reportOnSignal: false,
    reportOnUncaughtException: false,
    getReport: /* @__PURE__ */ notImplemented("process.report.getReport"),
    writeReport: /* @__PURE__ */ notImplemented("process.report.writeReport")
  };
  finalization = {
    register: /* @__PURE__ */ notImplemented("process.finalization.register"),
    unregister: /* @__PURE__ */ notImplemented("process.finalization.unregister"),
    registerBeforeExit: /* @__PURE__ */ notImplemented("process.finalization.registerBeforeExit")
  };
  memoryUsage = Object.assign(() => ({
    arrayBuffers: 0,
    rss: 0,
    external: 0,
    heapTotal: 0,
    heapUsed: 0
  }), { rss: () => 0 });
  mainModule = void 0;
  domain = void 0;
  send = void 0;
  exitCode = void 0;
  channel = void 0;
  getegid = void 0;
  geteuid = void 0;
  getgid = void 0;
  getgroups = void 0;
  getuid = void 0;
  setegid = void 0;
  seteuid = void 0;
  setgid = void 0;
  setgroups = void 0;
  setuid = void 0;
  _events = void 0;
  _eventsCount = void 0;
  _exiting = void 0;
  _maxListeners = void 0;
  _debugEnd = void 0;
  _debugProcess = void 0;
  _fatalException = void 0;
  _getActiveHandles = void 0;
  _getActiveRequests = void 0;
  _kill = void 0;
  _preload_modules = void 0;
  _rawDebug = void 0;
  _startProfilerIdleNotifier = void 0;
  _stopProfilerIdleNotifier = void 0;
  _tickCallback = void 0;
  _disconnect = void 0;
  _handleQueue = void 0;
  _pendingMessage = void 0;
  _channel = void 0;
  _send = void 0;
  _linkedBinding = void 0;
};
__name(Process, "Process");

// node_modules/@cloudflare/unenv-preset/dist/runtime/node/process.mjs
var globalProcess = globalThis["process"];
var getBuiltinModule = globalProcess.getBuiltinModule;
var { exit, platform, nextTick } = getBuiltinModule(
  "node:process"
);
var unenvProcess = new Process({
  env: globalProcess.env,
  hrtime,
  nextTick
});
var {
  abort,
  addListener,
  allowedNodeEnvironmentFlags,
  hasUncaughtExceptionCaptureCallback,
  setUncaughtExceptionCaptureCallback,
  loadEnvFile,
  sourceMapsEnabled,
  arch,
  argv,
  argv0,
  chdir,
  config,
  connected,
  constrainedMemory,
  availableMemory,
  cpuUsage,
  cwd,
  debugPort,
  dlopen,
  disconnect,
  emit,
  emitWarning,
  env,
  eventNames,
  execArgv,
  execPath,
  finalization,
  features,
  getActiveResourcesInfo,
  getMaxListeners,
  hrtime: hrtime3,
  kill,
  listeners,
  listenerCount,
  memoryUsage,
  on,
  off,
  once,
  pid,
  ppid,
  prependListener,
  prependOnceListener,
  rawListeners,
  release,
  removeAllListeners,
  removeListener,
  report,
  resourceUsage,
  setMaxListeners,
  setSourceMapsEnabled,
  stderr,
  stdin,
  stdout,
  title,
  throwDeprecation,
  traceDeprecation,
  umask,
  uptime,
  version,
  versions,
  domain,
  initgroups,
  moduleLoadList,
  reallyExit,
  openStdin,
  assert: assert2,
  binding,
  send,
  exitCode,
  channel,
  getegid,
  geteuid,
  getgid,
  getgroups,
  getuid,
  setegid,
  seteuid,
  setgid,
  setgroups,
  setuid,
  permission,
  mainModule,
  _events,
  _eventsCount,
  _exiting,
  _maxListeners,
  _debugEnd,
  _debugProcess,
  _fatalException,
  _getActiveHandles,
  _getActiveRequests,
  _kill,
  _preload_modules,
  _rawDebug,
  _startProfilerIdleNotifier,
  _stopProfilerIdleNotifier,
  _tickCallback,
  _disconnect,
  _handleQueue,
  _pendingMessage,
  _channel,
  _send,
  _linkedBinding
} = unenvProcess;
var _process = {
  abort,
  addListener,
  allowedNodeEnvironmentFlags,
  hasUncaughtExceptionCaptureCallback,
  setUncaughtExceptionCaptureCallback,
  loadEnvFile,
  sourceMapsEnabled,
  arch,
  argv,
  argv0,
  chdir,
  config,
  connected,
  constrainedMemory,
  availableMemory,
  cpuUsage,
  cwd,
  debugPort,
  dlopen,
  disconnect,
  emit,
  emitWarning,
  env,
  eventNames,
  execArgv,
  execPath,
  exit,
  finalization,
  features,
  getBuiltinModule,
  getActiveResourcesInfo,
  getMaxListeners,
  hrtime: hrtime3,
  kill,
  listeners,
  listenerCount,
  memoryUsage,
  nextTick,
  on,
  off,
  once,
  pid,
  platform,
  ppid,
  prependListener,
  prependOnceListener,
  rawListeners,
  release,
  removeAllListeners,
  removeListener,
  report,
  resourceUsage,
  setMaxListeners,
  setSourceMapsEnabled,
  stderr,
  stdin,
  stdout,
  title,
  throwDeprecation,
  traceDeprecation,
  umask,
  uptime,
  version,
  versions,
  // @ts-expect-error old API
  domain,
  initgroups,
  moduleLoadList,
  reallyExit,
  openStdin,
  assert: assert2,
  binding,
  send,
  exitCode,
  channel,
  getegid,
  geteuid,
  getgid,
  getgroups,
  getuid,
  setegid,
  seteuid,
  setgid,
  setgroups,
  setuid,
  permission,
  mainModule,
  _events,
  _eventsCount,
  _exiting,
  _maxListeners,
  _debugEnd,
  _debugProcess,
  _fatalException,
  _getActiveHandles,
  _getActiveRequests,
  _kill,
  _preload_modules,
  _rawDebug,
  _startProfilerIdleNotifier,
  _stopProfilerIdleNotifier,
  _tickCallback,
  _disconnect,
  _handleQueue,
  _pendingMessage,
  _channel,
  _send,
  _linkedBinding
};
var process_default = _process;

// node_modules/wrangler/_virtual_unenv_global_polyfill-@cloudflare-unenv-preset-node-process
globalThis.process = process_default;

// src/index.js
import { Buffer as Buffer2 } from "node:buffer";
var CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type"
};
var WA_API = "https://graph.facebook.com/v20.0";
var src_default = {
  getAllowedOrigin(request) {
    const origin = request.headers.get("Origin") || "";
    const allowed = [
      "https://smricambi.it",
      "https://www.smricambi.it",
      "https://smricambi-bot.pages.dev"
    ];
    return allowed.includes(origin) ? origin : "https://smricambi.it";
  },
  buildCORS(request) {
    return {
      "Access-Control-Allow-Origin": this.getAllowedOrigin(request),
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization"
    };
  },
  isAuthorizedAdmin(request, env2) {
    const auth = request.headers.get("Authorization") || "";
    const bearer = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    return !!env2?.VERIFY_TOKEN && bearer === env2.VERIFY_TOKEN;
  },
  async verifyWhatsAppWebhook(request, env2, url) {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");
    if (mode === "subscribe" && token && env2?.WHATSAPP_VERIFY_TOKEN && token === env2.WHATSAPP_VERIFY_TOKEN)
      return new Response(challenge || "OK", { status: 200, headers: this.buildCORS(request) });
    return new Response("Forbidden", { status: 403, headers: this.buildCORS(request) });
  },
  // =================================================================
  // CORE & SCUDO ANTI-CRASH
  // =================================================================
  async getSafeJSON(env2, key, defaultVal) {
    try {
      if (!env2.SMR_DB)
        return defaultVal;
      const raw = await env2.SMR_DB.get(key);
      if (raw === null || raw === "null" || typeof raw === "undefined")
        return defaultVal;
      return JSON.parse(raw);
    } catch (e) {
      return defaultVal;
    }
  },
  async scheduled(event, env2, ctx) {
    if (!env2.SMR_DB || !env2.SMR_BUCKET)
      return;
    try {
      const list = await env2.SMR_DB.list();
      let backupData = {};
      for (const k of list.keys) {
        backupData[k.name] = await env2.SMR_DB.get(k.name);
      }
      await env2.SMR_BUCKET.put(
        `backup/db_backup_${(/* @__PURE__ */ new Date()).toISOString().split("T")[0]}.json`,
        JSON.stringify(backupData),
        { httpMetadata: { contentType: "application/json" } }
      );
    } catch (e) {
      console.error("Backup Error", e);
    }
  },
  async fetch(request, env2, ctx) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS")
      return new Response(null, { headers: this.buildCORS(request) });
    if (!env2.SMR_DB)
      return new Response("ERRORE: SMR_DB non trovato.", { status: 500, headers: this.buildCORS(request) });
    try {
      if (url.pathname === "/admin")
        return new Response(this.getAdminHTML(), { headers: { "Content-Type": "text/html;charset=UTF-8" } });
      if (url.pathname === "/api/chats")
        return this.handleChatSnapshot(request, env2);
      if (url.pathname === "/api/chat_detail")
        return this.handleSingleChat(request, env2);
      if (url.pathname === "/api/widget")
        return this.handleWidget(request, env2, ctx);
      if (url.pathname === "/api/reply")
        return this.handleReply(request, env2);
      if (url.pathname === "/api/ingest")
        return this.handleIngest(request, env2);
      if (url.pathname === "/api/toggle")
        return this.handleToggle(request, env2);
      if (url.pathname === "/api/resolve")
        return this.handleResolve(request, env2);
      if (url.pathname === "/api/delete")
        return this.handleDelete(request, env2);
      if (url.pathname === "/api/reset-db") {
        if (!this.isAuthorizedAdmin(request, env2))
          return new Response("Unauthorized", { status: 401, headers: this.buildCORS(request) });
        return this.handleResetDB(env2);
      }
      if (url.pathname === "/api/upload" && request.method === "POST")
        return this.handleUpload(request, env2);
      if (url.pathname.startsWith("/api/media/"))
        return this.handleMedia(url, env2);
      if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/webhook"))
        return this.verifyWhatsAppWebhook(request, env2, url);
      if (request.method === "POST") {
        const body = await request.json();
        const msg = body?.entry?.[0]?.changes?.[0]?.value?.messages?.[0];
        const name = body?.entry?.[0]?.changes?.[0]?.value?.contacts?.[0]?.profile?.name || "Cliente WA";
        if (msg)
          ctx.waitUntil(this.handleWhatsApp(msg, name, env2, ctx));
        return new Response("OK");
      }
      return new Response("SMR OS V46 ACTIVE");
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: this.buildCORS(request) });
    }
  },
  // =================================================================
  // MOTORE DI OTTIMIZZAZIONE & RECOVERY
  // =================================================================
  async handleChatSnapshot(request, env2) {
    const url = new URL(request.url);
    const forceSync = url.searchParams.get("force") === "true";
    let snapshot = await this.getSafeJSON(env2, "crm_snapshot", null);
    if (forceSync || !snapshot || Object.keys(snapshot).length === 0) {
      snapshot = snapshot || {};
      try {
        const list = await env2.SMR_DB.list({ prefix: "chat_" });
        for (const k of list.keys) {
          const phone = k.name.replace("chat_", "");
          const messages = await this.getSafeJSON(env2, k.name, []);
          const status = await this.getSafeJSON(env2, `status_${phone}`, { name: "Sconosciuto", channel: "whatsapp", resolved: false });
          if (messages.length > 0) {
            snapshot[phone] = { status, lastMessage: messages[messages.length - 1], lastUpdate: messages[messages.length - 1].timestamp };
          }
        }
        await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snapshot));
      } catch (e) {
        console.error("Sync Error", e);
      }
    }
    let chats = Object.keys(snapshot).map((phone) => {
      let data = snapshot[phone];
      return { phone, ...data.status || {}, messages: data.lastMessage ? [data.lastMessage] : [], lastUpdate: data.lastUpdate || 0 };
    });
    chats.sort((a, b) => b.lastUpdate - a.lastUpdate);
    return new Response(JSON.stringify(chats), { headers: CORS });
  },
  async handleSingleChat(request, env2) {
    const phone = new URL(request.url).searchParams.get("phone");
    if (!phone)
      return new Response("[]", { headers: CORS });
    const messages = await this.getSafeJSON(env2, `chat_${phone}`, []);
    return new Response(JSON.stringify(messages), { headers: CORS });
  },
  async saveLog(p, obj, env2, statusObj) {
    let chat = await this.getSafeJSON(env2, `chat_${p}`, []);
    if (!Array.isArray(chat))
      chat = [];
    chat.push(obj);
    await env2.SMR_DB.put(`chat_${p}`, JSON.stringify(chat.slice(-150)));
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (!snap[p])
      snap[p] = {};
    snap[p].status = statusObj || await this.getSafeJSON(env2, `status_${p}`, {});
    snap[p].lastMessage = obj;
    snap[p].lastUpdate = Date.now();
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
  },
  // =================================================================
  // OCR & FILE HANDLING (VISION IA & R2)
  // =================================================================
  async processImageOCR(mediaId, mediaType, from, env2, st) {
    try {
      let base64Image = "";
      if (mediaType === "image") {
        if (mediaId.startsWith("r2_")) {
          let obj = await env2.SMR_BUCKET.get(mediaId.replace("r2_", ""));
          let arrBuffer = await obj.arrayBuffer();
          base64Image = "data:image/jpeg;base64," + Buffer2.from(arrBuffer).toString("base64");
        } else {
          const infoRes = await fetch(`${WA_API}/${mediaId}`, { headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}` } });
          const info3 = await infoRes.json();
          const mediaRes = await fetch(info3.url, { headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}` } });
          let arrBuffer = await mediaRes.arrayBuffer();
          base64Image = "data:image/jpeg;base64," + Buffer2.from(arrBuffer).toString("base64");
        }
      }
      if (base64Image) {
        const aiRes = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: { "Authorization": `Bearer ${env2.OPENAI_API_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            messages: [{ role: "user", content: [
              { type: "text", text: "Estrai SOLAMENTE questi dati se presenti: Codice Caldaia/Clima, Matricola completa, Modello completo, Anno. Rispondi in formato elenco pulito." },
              { type: "image_url", image_url: { url: base64Image } }
            ] }],
            temperature: 0.1
          })
        });
        const aiData = await aiRes.json();
        let note = `\u{1F4DD} DATI ESTRATTI DALLA TARGHETTA:
${aiData.choices[0].message.content}`;
        await this.saveLog(from, { from: "system", text: note, timestamp: Date.now() }, env2, st);
      }
    } catch (e) {
      console.error("OCR Failed", e);
    }
  },
  async handleUpload(request, env2) {
    try {
      const formData = await request.formData();
      const file = formData.get("file");
      if (!file)
        return new Response("Nessun file", { status: 400, headers: CORS });
      const ext = file.name.split(".").pop();
      const fileName = `smr_${Date.now()}_${Math.random().toString(36).substring(7)}.${ext}`;
      await env2.SMR_BUCKET.put(fileName, file.stream(), { httpMetadata: { contentType: file.type } });
      return new Response(JSON.stringify({ url: `/api/media/r2_${fileName}`, type: file.type, name: file.name, id: fileName }), { headers: CORS });
    } catch (e) {
      return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS });
    }
  },
  async handleMedia(url, env2) {
    const mediaId = url.pathname.split("/")[3];
    if (!mediaId)
      return new Response("Missing ID", { status: 400, headers: CORS });
    try {
      if (mediaId.startsWith("r2_")) {
        const object = await env2.SMR_BUCKET.get(mediaId.replace("r2_", ""));
        if (!object)
          return new Response("Not found", { status: 404, headers: CORS });
        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set("Access-Control-Allow-Origin", "*");
        return new Response(object.body, { headers });
      } else {
        const infoRes = await fetch(`${WA_API}/${mediaId}`, { headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}` } });
        const info3 = await infoRes.json();
        const mediaRes = await fetch(info3.url, { headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}` } });
        return new Response(mediaRes.body, { headers: { "Content-Type": mediaRes.headers.get("content-type"), ...CORS } });
      }
    } catch (e) {
      return new Response("Error", { status: 500, headers: CORS });
    }
  },
  // =================================================================
  // GESTIONE MESSAGGI WIDGET & WHATSAPP
  // =================================================================
  // FIX: aggiunto parametro ctx per ctx.waitUntil()
  async handleWidget(request, env2, ctx) {
    const { userId, text, name, email, attachment, analytics } = await request.json();
    const channelId = `web_${userId}`;
    let st = await this.getSafeJSON(env2, `status_${channelId}`, { manual: false, resolved: false, tag: "NEUTRO" });
    st.name = name || st.name || "Visitatore Web";
    st.email = email || st.email;
    st.channel = "web";
    st.resolved = false;
    if (analytics) {
      await this.saveLog(channelId, { from: "system", text: `\u{1F441}\uFE0F Visitatore dalla pagina: ${analytics.url}`, timestamp: Date.now() }, env2, st);
    }
    let msgText = text || "";
    let mediaId = null;
    let mediaType = null;
    let fileName = null;
    if (attachment) {
      msgText = text || "\u{1F4CE} Allegato Inviato";
      mediaId = attachment.id || attachment.url.split("/").pop();
      mediaType = attachment.type.includes("image") ? "image" : "document";
      fileName = attachment.name;
    }
    if (msgText) {
      await this.saveLog(channelId, { from: "user", text: msgText, mediaId, mediaType, fileName, timestamp: Date.now() }, env2, st);
    }
    if (mediaId) {
      st.manual = true;
      st.until = Date.now() + 864e5 * 2;
      st.tag = "VENDITA";
      await env2.SMR_DB.put(`status_${channelId}`, JSON.stringify(st));
      let reply = "Ho ricevuto il documento. Un nostro tecnico specializzato lo sta verificando e ti risponder\xE0 qui a breve.";
      await this.saveLog(channelId, { from: "bot", text: reply, timestamp: Date.now() }, env2, st);
      ctx.waitUntil(this.processImageOCR(mediaId, mediaType, channelId, env2, st));
      return new Response(JSON.stringify({ reply, buttons: null }), { headers: CORS });
    }
    if (st.manual && st.until > Date.now())
      return new Response(JSON.stringify({ reply: "" }), { headers: CORS });
    const history = await this.getSafeJSON(env2, `chat_${channelId}`, []);
    const showBtns = history.length <= 3;
    const aiData = await this.generateAI(msgText, env2, showBtns, st);
    st.tag = aiData.tag;
    await env2.SMR_DB.put(`status_${channelId}`, JSON.stringify(st));
    await this.saveLog(channelId, { from: "bot", text: aiData.text, timestamp: Date.now() }, env2, st);
    return new Response(JSON.stringify({ reply: aiData.text, buttons: aiData.buttons }), { headers: CORS });
  },
  // FIX: aggiunto parametro ctx per ctx.waitUntil()
  async handleWhatsApp(m, name, env2, ctx) {
    const from = m.from;
    let text = "";
    let mediaId = null;
    let mediaType = null;
    if (m.type === "text") {
      text = m.text.body;
    } else if (m.type === "interactive") {
      text = m.interactive?.button_reply?.title || m.interactive?.list_reply?.title || "";
    } else if (m.type === "image") {
      text = m.image.caption || "\u{1F4F7} Foto Ricevuta";
      mediaId = m.image.id;
      mediaType = "image";
    } else if (m.type === "document") {
      text = m.document.caption || "\u{1F4C4} Documento Ricevuto";
      mediaId = m.document.id;
      mediaType = "document";
    }
    if (!text && !mediaId)
      return;
    let st = await this.getSafeJSON(env2, `status_${from}`, { manual: false, resolved: false, tag: "NEUTRO" });
    st.name = name;
    st.channel = "whatsapp";
    st.resolved = false;
    st.lastUserInteraction = Date.now();
    await this.saveLog(from, { from: "user", text, mediaId, mediaType, timestamp: Date.now() }, env2, st);
    const history = await this.getSafeJSON(env2, `chat_${from}`, []);
    if (history.length <= 1 && !mediaId) {
      let welcomeMsg = {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: from,
        type: "interactive",
        interactive: {
          type: "button",
          body: { text: "Benvenuto! Sono l'assistente IA di S.M. Ricambi.\n\nSeleziona un'opzione o scrivi il tuo problema:" },
          action: {
            buttons: [
              { type: "reply", reply: { id: "btn_ordini", title: "Stato Ordini" } },
              { type: "reply", reply: { id: "btn_compat", title: "Compatibilita" } },
              { type: "reply", reply: { id: "btn_assist", title: "Assistenza" } }
            ]
          }
        }
      };
      await fetch(`${WA_API}/${env2.WHATSAPP_PHONE_ID}/messages`, {
        method: "POST",
        headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" },
        body: JSON.stringify(welcomeMsg)
      });
      await this.saveLog(from, { from: "bot", text: "Benvenuto! Sono l'assistente IA di S.M. Ricambi. [Inviati Pulsanti Scelta Rapida]", timestamp: Date.now() }, env2, st);
      return;
    }
    if (mediaId) {
      st.manual = true;
      st.until = Date.now() + 864e5 * 2;
      st.tag = "VENDITA";
      await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st));
      let reply = "Ho ricevuto il documento. Passo subito la chat a un nostro operatore umano che verificher\xE0 tutto e ti risponder\xE0 qui a breve.";
      await fetch(`${WA_API}/${env2.WHATSAPP_PHONE_ID}/messages`, { method: "POST", headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" }, body: JSON.stringify({ messaging_product: "whatsapp", to: from, text: { body: reply } }) });
      await this.saveLog(from, { from: "bot", text: reply, timestamp: Date.now() }, env2, st);
      ctx.waitUntil(this.processImageOCR(mediaId, mediaType, from, env2, st));
      return;
    }
    if (st.manual && st.until > Date.now()) {
      await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st));
      return;
    }
    const aiData = await this.generateAI(text, env2, false, st);
    st.tag = aiData.tag;
    await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st));
    await fetch(`${WA_API}/${env2.WHATSAPP_PHONE_ID}/messages`, {
      method: "POST",
      headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ messaging_product: "whatsapp", to: from, text: { body: aiData.text } })
    });
    await this.saveLog(from, { from: "bot", text: aiData.text, timestamp: Date.now() }, env2, st);
  },
  // =================================================================
  // INTELLIGENZA ARTIFICIALE E OMNI-LEARNING
  // =================================================================
  async generateAI(userText, env2, showBtns, st) {
    const emb = await env2.AI.run("@cf/baai/bge-base-en-v1.5", { text: [userText] });
    const matches = await env2.VECTORIZE_INDEX.query(emb.data[0], { topK: 5, returnMetadata: "all" });
    const context2 = matches.matches.filter((x) => x.score > 0.45).map((x) => x.metadata.text).join("\n\n");
    const sysPrompt = `Sei l'assistente IA ufficiale di S.M. Ricambi (smricambi.com).
REGOLE TASSATIVE:
1. NOI SIAMO S.M. Ricambi. Mai nominare concorrenti.
2. PROTOCOLLO TARGHETTA: Per identificare un ricambio, chiedi SEMPRE al cliente la 'targhetta identificativa interna della caldaia/scaldabagno con indicati modello completo e matricola'.
3. Se il cliente non ha la targhetta, digli che lo passi ad un operatore umano per sicurezza.
4. Non inventare MAI codici. Affidati a: ${context2}.
5. TRIAGE: Inizia SEMPRE la risposta con un Tag esatto seguito da un |: [VENDITA], [ORDINE], [TECNICO], [URGENTE], [NEUTRO]. Esempio: [VENDITA]|Risposta...`;
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${env2.OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: "gpt-4o-mini", messages: [{ role: "system", content: sysPrompt }, { role: "user", content: userText }], temperature: 0.15 })
    });
    const data = await res.json();
    let rawText = data.choices[0].message.content;
    let tag = st.tag || "NEUTRO";
    if (rawText.includes("|")) {
      let parts = rawText.split("|");
      let potentialTag = parts[0].replace("[", "").replace("]", "").trim();
      if (["VENDITA", "ORDINE", "TECNICO", "URGENTE", "NEUTRO"].includes(potentialTag)) {
        tag = potentialTag;
        rawText = parts.slice(1).join("|").trim();
      }
    }
    return {
      text: rawText,
      tag,
      buttons: showBtns ? ["\u{1F4E6} Stato Ordini", "\u{1F527} Compatibilit\xE0", "\u{1F468}\u200D\u{1F527} Assistenza"] : null
    };
  },
  async handleIngest(request, env2) {
    try {
      const body = await request.json();
      let type = body.type || "text";
      let content = body.content || body.text || "";
      let source = body.source || "SMR Vault";
      let textToMemorize = "";
      if (type === "text") {
        textToMemorize = content;
      } else if (type === "url") {
        const res = await fetch(content);
        if (!res.ok)
          throw new Error("Link inaccessibile");
        textToMemorize = (await res.text()).replace(/<[^>]+>/ig, " ").replace(/\s{2,}/g, " ").trim();
      } else if (type === "image") {
        const aiRes = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: { "Authorization": `Bearer ${env2.OPENAI_API_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify({ model: "gpt-4o-mini", messages: [{ role: "user", content: [{ type: "text", text: "Estrai dati tecnici." }, { type: "image_url", image_url: { url: content } }] }], temperature: 0.1 })
        });
        const aiData = await aiRes.json();
        textToMemorize = aiData.choices[0].message.content;
      }
      if (!textToMemorize || textToMemorize.trim().length === 0)
        return new Response("Nessun dato", { status: 400, headers: CORS });
      const safeText = textToMemorize.substring(0, 1900);
      const kbId = `kb_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      const emb = await env2.AI.run("@cf/baai/bge-base-en-v1.5", { text: [safeText] });
      await env2.VECTORIZE_INDEX.upsert([{ id: kbId, values: emb.data[0], metadata: { text: safeText, source } }]);
      await env2.SMR_DB.put(kbId, JSON.stringify({ text: safeText, type, source, timestamp: Date.now() }));
      return new Response(JSON.stringify({ ok: true, extracted: safeText }), { headers: CORS });
    } catch (e) {
      return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS });
    }
  },
  // =================================================================
  // AZIONI CRM ADMIN
  // =================================================================
  async handleReply(request, env2) {
    const { phone, text, isNote, mediaUrl, mediaType, fileName, template } = await request.json();
    let st = await this.getSafeJSON(env2, `status_${phone}`, {});
    if (isNote) {
      await this.saveLog(phone, { from: "system", text: `\u{1F4DD} NOTA INTERNA: ${text}`, timestamp: Date.now() }, env2, st);
      return new Response(JSON.stringify({ ok: true }), { headers: CORS });
    }
    if (!phone.startsWith("web_")) {
      let payload = { messaging_product: "whatsapp", to: phone };
      if (template) {
        payload.type = "template";
        payload.template = { name: template, language: { code: "it" } };
      } else if (mediaUrl) {
        let directUrl = new URL(request.url).origin + mediaUrl;
        payload.type = mediaType.includes("image") ? "image" : "document";
        payload[payload.type] = { link: directUrl, caption: text || "" };
      } else {
        payload.type = "text";
        payload.text = { body: text };
      }
      await fetch(`${WA_API}/${env2.WHATSAPP_PHONE_ID}/messages`, { method: "POST", headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" }, body: JSON.stringify(payload) });
    }
    let logObj = { from: "admin", text, timestamp: Date.now() };
    if (mediaUrl) {
      logObj.mediaId = mediaUrl.split("/").pop().replace("r2_", "");
      logObj.mediaType = mediaType;
      logObj.fileName = fileName;
    }
    await this.saveLog(phone, logObj, env2, st);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },
  async handleToggle(request, env2) {
    const { phone, manual } = await request.json();
    let st = await this.getSafeJSON(env2, `status_${phone}`, {});
    st.manual = manual;
    st.until = manual ? Date.now() + 864e5 * 2 : 0;
    st.resolved = false;
    await env2.SMR_DB.put(`status_${phone}`, JSON.stringify(st));
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (snap[phone]) {
      snap[phone].status = st;
      snap[phone].lastUpdate = Date.now();
    }
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
    await this.saveLog(phone, { from: "system", text: manual ? "L'operatore ha preso il controllo." : "Controllo ripassato all'Intelligenza Artificiale.", timestamp: Date.now() }, env2, st);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },
  async handleResolve(request, env2) {
    const { phone } = await request.json();
    let st = await this.getSafeJSON(env2, `status_${phone}`, {});
    st.resolved = true;
    st.manual = false;
    st.until = 0;
    await env2.SMR_DB.put(`status_${phone}`, JSON.stringify(st));
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (snap[phone]) {
      snap[phone].status = st;
      snap[phone].lastUpdate = Date.now();
    }
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
    await this.saveLog(phone, { from: "system", text: "Conversazione risolta e archiviata.", timestamp: Date.now() }, env2, st);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },
  async handleResetDB(env2) {
    const list = await env2.SMR_DB.list({ prefix: "chat_" });
    for (const k of list.keys) {
      await env2.SMR_DB.delete(k.name);
      await env2.SMR_DB.delete(k.name.replace("chat_", "status_"));
    }
    await env2.SMR_DB.delete("crm_snapshot");
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },
  async handleDelete(request, env2) {
    const { phone } = await request.json();
    await env2.SMR_DB.delete(`chat_${phone}`);
    await env2.SMR_DB.delete(`status_${phone}`);
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    delete snap[phone];
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },
  // =================================================================
  // INTERFACCIA GRAFICA CRM (MOBILE FIX & TOAST)
  // =================================================================
  getAdminHTML() {
    return `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>SMR OS - Premium Edition</title>
  <script src="https://cdn.tailwindcss.com"><\/script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    body { font-family: 'Inter', sans-serif; background-color: #ffffff; color: #1e293b; overflow: hidden; }
    ::-webkit-scrollbar { width: 4px; height: 4px; }
    ::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 10px; }
    
    @media (max-width: 767px) {
      .desktop-only { display: none !important; }
      .mobile-view-chat #chatListContainer { display: none !important; }
      .mobile-view-chat #navBar { display: none !important; }
      #chatAreaContainer { display: none; }
      .mobile-view-chat #chatAreaContainer { display: flex !important; position: fixed; inset: 0; z-index: 100; background: #f8fafc; }
      .bottom-nav { position: fixed; bottom: 0; left: 0; right: 0; height: 60px; background: #0f172a; display: flex; justify-content: space-around; align-items: center; z-index: 50; }
    }
    
    .sidebar-icon { color: #94a3b8; transition: 0.2s; cursor: pointer; padding: 10px; border-radius: 10px; display: flex; flex-direction: column; align-items: center; }
    .sidebar-icon:hover { color: #ffffff; background: rgba(255,255,255,0.1); }
    .sidebar-icon.active { color: #3b82f6; }
    
    .chat-item { transition: all 0.2s ease; border-left: 3px solid transparent; }
    .chat-item:hover { background-color: #f8fafc; }
    .chat-item.active { background-color: #eff6ff; border-left-color: #3b82f6; }
    .unread-wa { background-color: #f0fdf4; border-left-color: #22c55e; }
    .unread-web { background-color: #eff6ff; border-left-color: #3b82f6; }
    
    .msg-bubble { max-width: 85%; padding: 12px 16px; border-radius: 16px; font-size: 14px; line-height: 1.5; box-shadow: 0 2px 4px rgba(0,0,0,0.04); word-break: break-word; }
    .msg-admin { background: linear-gradient(135deg, #0057ff 0%, #0047d1 100%); color: #ffffff; border-bottom-right-radius: 4px; }
    .msg-user { background-color: #ffffff; color: #1e293b; border-bottom-left-radius: 4px; border: 1px solid #e2e8f0; }
    .msg-bot { background-color: #ffffff; color: #0057ff; border-bottom-left-radius: 4px; border: 1px solid #bfdbfe; font-weight: 500; }
    .msg-system { background-color: #fefce8; color: #a16207; border-radius: 8px; font-size: 12px; width: 100%; padding: 8px 12px; border: 1px solid #fef08a;}
    
    .tab-btn { cursor: pointer; border-bottom: 2px solid transparent; padding-bottom: 8px; font-weight: 500; color: #64748b; transition: 0.2s; }
    .tab-btn.active { border-bottom: 2px solid #2563eb; color: #2563eb; font-weight: 700; }
    .t-tab { cursor: pointer; padding: 8px 12px; border-bottom: 2px solid transparent; font-weight:500; color:#64748b;}
    .t-tab.active { border-color: #2563eb; color:#2563eb; font-weight:700;}

    .badge-vendita { background: #dcfce7; color: #166534; border: 1px solid #bbf7d0; }
    .badge-tecnico { background: #fee2e2; color: #991b1b; border: 1px solid #fecaca; }
    .badge-ordine { background: #e0e7ff; color: #1e40af; border: 1px solid #bfdbfe; }
    .badge-neutro { background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0; }
  </style>
</head>
<body class="h-screen w-full flex overflow-hidden">
  
  <div id="toastBox" class="fixed top-5 left-1/2 transform -translate-x-1/2 z-[9999] transition-all duration-300 opacity-0 pointer-events-none flex items-center bg-slate-800 text-white px-6 py-3 rounded-full shadow-2xl text-sm font-semibold -translate-y-4">
       <span id="toastMsg">Sincronizzazione completata!</span>
  </div>

  <aside id="navBar" class="w-[72px] bg-[#0f172a] hidden md:flex flex-col items-center py-6 gap-4 z-40 border-r border-slate-800 bottom-nav">
    <div class="hidden md:flex w-10 h-10 bg-gradient-to-tr from-blue-500 to-indigo-600 rounded-xl items-center justify-center text-white font-bold mb-4 shadow-lg">SM</div>
    <div class="sidebar-icon active" onclick="showView('chats')" title="Conversazioni">
        <svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>
        <span class="text-[9px] mt-1 md:hidden">Chat</span>
    </div>
    <div class="sidebar-icon" onclick="showT()" title="Centro Apprendimento IA">
        <svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"></path><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"></path></svg>
        <span class="text-[9px] mt-1 md:hidden">Vault</span>
    </div>
    <div class="sidebar-icon md:mt-auto text-blue-400" onclick="forceSync()" title="Forza Sync">
        <svg width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg>
        <span class="text-[9px] mt-1 md:hidden">Sync</span>
    </div>
  </aside>

  <aside id="chatListContainer" class="w-full md:w-[340px] bg-white border-r border-slate-200 flex flex-col z-20 pb-16 md:pb-0">
    <div class="p-5 border-b border-slate-100 shadow-sm z-10 bg-white">
      <div class="flex justify-between items-center mb-5">
        <h2 class="font-bold text-2xl text-slate-800 tracking-tight">Inbox</h2>
        <div class="flex items-center gap-1.5 bg-emerald-50 text-emerald-600 px-2.5 py-1 rounded-md border border-emerald-100">
           <div class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></div>
           <span class="text-xs font-bold">Online</span>
        </div>
      </div>
      <div class="flex gap-2 mb-4">
        <button id="tabOpen" onclick="setTab(false)" class="tab-btn active flex-1 text-center text-sm transition">Aperte</button>
        <button id="tabArchived" onclick="setTab(true)" class="tab-btn flex-1 text-center text-sm transition">Archivio</button>
      </div>
      <div class="relative">
        <svg class="w-4 h-4 absolute left-3 top-3 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
        <input type="text" id="search" placeholder="Cerca conversazione..." class="w-full text-sm bg-slate-50 pl-9 pr-4 py-2.5 rounded-xl border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500 transition" oninput="renderL()">
      </div>
    </div>
    <div id="chatList" class="flex-1 overflow-y-auto bg-white"></div>
  </aside>

  <main id="chatAreaContainer" class="flex-1 flex-col relative bg-[#f8fafc] hidden md:flex pb-0">
    
    <div id="tZone" class="hidden absolute inset-0 bg-slate-900/70 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
      <div class="bg-white rounded-3xl shadow-2xl p-8 w-full max-w-4xl border border-slate-100">
        <div class="flex justify-between items-center mb-6">
            <div>
                <h2 class="text-2xl font-bold text-slate-800 flex items-center gap-2">\u{1F9E0} SMR Vault</h2>
                <p class="text-sm text-slate-500 mt-1">Addestramento permanente. I dati non verranno mai cancellati.</p>
            </div>
            <button onclick="hideT()" class="text-xl text-slate-400 hover:text-slate-800 bg-slate-100 hover:bg-slate-200 p-2 rounded-full w-10 h-10 flex items-center justify-center transition">\u2715</button>
        </div>
        <div class="flex gap-6 border-b border-slate-200 mb-6">
            <div id="t-tab-text" class="t-tab active" onclick="switchTrainTab('text')">\u{1F4DD} Regole Testuali</div>
            <div id="t-tab-link" class="t-tab" onclick="switchTrainTab('link')">\u{1F517} Analisi Link</div>
            <div id="t-tab-img" class="t-tab" onclick="switchTrainTab('img')">\u{1F5BC}\uFE0F Lettura Immagini</div>
        </div>
        <div id="t-content-text" class="t-content block"><textarea id="tText" class="w-full h-56 border border-slate-200 bg-slate-50 p-5 rounded-2xl outline-none focus:ring-2 focus:ring-blue-500 text-sm resize-none"></textarea></div>
        <div id="t-content-link" class="t-content hidden"><input type="url" id="tLink" class="w-full border border-slate-200 bg-slate-50 p-4 rounded-2xl outline-none focus:ring-2 focus:ring-blue-500 text-sm"></div>
        <div id="t-content-img" class="t-content hidden"><input type="file" id="tImgFile" accept="image/*" class="w-full border border-slate-200 bg-slate-50 p-4 rounded-2xl text-sm" onchange="previewTrainImage()"><img id="tImgPreview" class="mt-4 max-h-32 rounded-lg hidden shadow-sm border border-slate-200"><input type="hidden" id="tImgBase64"></div>
        <div class="mt-6 flex justify-end gap-3">
            <button onclick="hideT()" class="px-6 py-3.5 rounded-xl font-bold text-slate-600 hover:bg-slate-100 transition">Annulla</button>
            <button onclick="saveOmni()" id="tBtn" class="bg-blue-600 text-white px-8 py-3.5 rounded-xl font-bold hover:bg-blue-700 transition shadow-lg">Salva nel Vault</button>
        </div>
      </div>
    </div>

    <div id="empty" class="absolute inset-0 flex flex-col items-center justify-center text-slate-400 z-0 bg-[#f8fafc]">
      <svg width="64" height="64" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24" class="mb-4 opacity-30"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>
      <p class="font-medium text-lg">Seleziona una conversazione</p>
    </div>

    <header id="chatH" class="h-[76px] border-b border-slate-200 px-4 md:px-8 flex items-center justify-between z-10 hidden bg-white shadow-sm shrink-0">
      <div class="flex items-center gap-3 md:gap-4 w-full">
        <button onclick="closeChatMobile()" class="md:hidden p-2 -ml-2 text-slate-500"><svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"></path></svg></button>
        <div class="w-12 h-12 rounded-full flex items-center justify-center font-bold text-white text-lg shadow-md shrink-0" id="hAvatar"></div>
        <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2"><div id="hName" class="font-bold text-slate-800 text-base leading-tight truncate"></div><div id="hTagBadge" class="text-[9px] font-bold px-1.5 py-0.5 rounded uppercase hidden md:block"></div></div>
            <div id="hDetails" class="text-xs text-slate-500 mt-0.5 truncate"></div>
        </div>
      </div>
      <div class="flex items-center gap-2 md:gap-3 shrink-0">
        <button id="resolveBtn" onclick="resolveChat()" class="px-3 md:px-4 py-2 rounded-xl text-xs font-bold text-emerald-700 bg-emerald-50 hover:bg-emerald-100 border border-emerald-200 transition shadow-sm hidden"><span class="hidden md:inline">Risolvi & Archivia</span><span class="md:hidden">Risolvi</span></button>
        <button id="toggleBtn" onclick="toggleM()" class="px-3 md:px-5 py-2 md:py-2.5 rounded-xl text-xs font-bold border transition shadow-sm"></button>
        <button onclick="delChat()" class="p-2.5 text-slate-400 hover:text-red-500 rounded-xl hover:bg-red-50 transition" title="Elimina Chat"><svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg></button>
      </div>
    </header>

    <div id="msgA" class="flex-1 overflow-y-auto p-4 md:p-8 space-y-5 z-10 hidden bg-[#f8fafc]"></div>

    <div id="compWrapper" class="hidden flex-col z-10 border-t border-slate-200 bg-white">
      <div id="waNotice" class="hidden bg-amber-50 border-b border-amber-100 px-4 py-2 text-[11px] text-amber-800 font-medium items-center justify-between">
          <span>\u26A0\uFE0F WhatsApp 24h limit reached.</span>
          <select id="waTemplateSelect" class="bg-white border border-amber-200 rounded px-2 py-1 outline-none text-amber-900 font-semibold">
              <option value="">Scegli Template Approvato...</option>
              <option value="ordine_spedito">Ordine Spedito</option>
              <option value="ricambio_disponibile">Ricambio Disponibile</option>
          </select>
      </div>

      <div class="px-4 md:px-6 py-2.5 bg-slate-50 border-b border-slate-100 flex gap-2 overflow-x-auto no-scrollbar">
        <button onclick="sendNote()" class="text-[11px] shrink-0 font-semibold bg-yellow-50 border border-yellow-200 px-4 py-1.5 rounded-full text-yellow-800 transition">\u{1F4DD} Nota Segreta</button>
        <button onclick="insertQuick('Per verificare la compatibilit\xE0 mi serve una foto della targhetta della caldaia.')" class="text-[11px] shrink-0 font-medium bg-white border border-slate-200 px-4 py-1.5 rounded-full text-slate-600 transition hover:bg-slate-100">Foto Targhetta</button>
        <button onclick="insertQuick('Il ricambio \xE8 disponibile a magazzino. Se ordini ora spediamo in giornata.')" class="text-[11px] shrink-0 font-medium bg-white border border-slate-200 px-4 py-1.5 rounded-full text-slate-600 transition hover:bg-slate-100">Disponibile</button>
      </div>
      
      <form id="comp" class="p-3 md:p-5 flex gap-2 md:gap-4 items-end">
        <input type="file" id="adminFile" class="hidden" onchange="previewFile()">
        <button type="button" onclick="document.getElementById('adminFile').click()" class="p-2 md:p-3 shrink-0 text-slate-500 hover:text-blue-600 bg-slate-100 rounded-full transition"><svg width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path></svg></button>
        <div id="filePreview" class="hidden text-[11px] font-bold text-blue-600 bg-blue-50 px-3 py-2 rounded-lg border border-blue-200 items-center gap-2 max-w-[100px] md:max-w-[150px] truncate shrink-0"></div>
        <textarea id="msgI" class="flex-1 bg-white border border-slate-300 focus:border-blue-500 rounded-2xl px-5 py-3.5 outline-none text-sm resize-none shadow-sm" rows="1" style="min-height: 48px; max-height: 120px;" placeholder="Scrivi una risposta..."></textarea>
        <button type="submit" id="sendBtn" class="bg-gradient-to-tr from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white p-3 md:px-8 md:py-3.5 rounded-full font-bold transition md:h-[50px] shadow-lg flex items-center justify-center shrink-0">
            <svg class="w-5 h-5 md:hidden" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><line x1="22" y1="2" x2="11" y2="13"></line><polygon points="22 2 15 22 11 13 2 9 22 2"></polygon></svg>
            <span class="hidden md:inline">Invia</span>
        </button>
      </form>
    </div>
  </main>

<script>
var curr=null, chats=[], currentManual=false, viewArchived=false;
let currentTrainType = 'text'; let isWhatsApp24hExpired = false;

function showToast(msg) {
    var tb = document.getElementById('toastBox');
    document.getElementById('toastMsg').innerText = msg;
    tb.classList.remove('opacity-0', 'pointer-events-none', '-translate-y-4');
    setTimeout(() => tb.classList.add('opacity-0', 'pointer-events-none', '-translate-y-4'), 3000);
}

async function load(){ 
  try { 
    var r = await fetch('/api/chats'); 
    if(!r.ok) return;
    var d = await r.json(); 
    chats = Array.isArray(d) ? d : []; 
    renderL(); if(curr) fetchChatDetailAndRender(curr, true); 
  } catch(e) {} 
}

async function forceSync() {
    showToast("Sincronizzazione profonda in corso...");
    try { await fetch('/api/chats?force=true'); location.reload(); } catch(e) { showToast("Errore di sync."); }
}

async function fetchChatDetailAndRender(phone, silent = false) {
    try {
        var r = await fetch('/api/chat_detail?phone=' + phone);
        if(!r.ok) return;
        var msgs = await r.json();
        var c = chats.find(x => x.phone === phone);
        if (c) { c.messages = msgs; renderM(phone); }
    } catch(e) {}
}

function renderL() { 
  try {
    var q = document.getElementById('search').value.toLowerCase();
    var filtered = chats.filter(c => {
        var nameMatch = (c.name || '').toLowerCase().includes(q);
        var phoneMatch = (c.phone || '').includes(q);
        var archiveMatch = !!c.resolved === viewArchived;
        return (nameMatch || phoneMatch) && archiveMatch;
    });
    
    var htmlContent = "";

    filtered.forEach(c => {
      var msgs = Array.isArray(c.messages) ? c.messages : [];
      var lastMsg = msgs.length ? msgs[msgs.length - 1] : null;
      var lastText = lastMsg ? (lastMsg.text || '\u{1F4CE} Allegato') : ''; 
      
      if (lastMsg && lastMsg.from === 'system') lastText = '\u{1F4DD} ' + lastText.substring(0, 30) + '...';
      else if (lastText.length > 35) lastText = lastText.substring(0, 35) + '...';

      var time = lastMsg && lastMsg.timestamp ? new Date(lastMsg.timestamp).toLocaleTimeString('it-IT', {hour: '2-digit', minute: '2-digit'}) : '';
      var storedReadTime = localStorage.getItem('read_' + c.phone) || 0;
      var isUnread = (lastMsg && lastMsg.from === 'user' && lastMsg.timestamp > storedReadTime && curr !== c.phone);
      
      var isWA = c.channel === 'whatsapp'; 
      var bgClass = isUnread ? (isWA ? 'unread-wa' : 'unread-web') : (curr === c.phone ? 'read-chat active' : 'read-chat'); 
      var badge = isUnread ? '<span class="flex h-3 w-3 absolute -top-1 -right-1"><span class="animate-ping absolute inline-flex h-full w-full rounded-full ' + (isWA ? 'bg-emerald-400' : 'bg-blue-400') + ' opacity-75"></span><span class="relative inline-flex rounded-full h-3 w-3 ' + (isWA ? 'bg-emerald-500' : 'bg-blue-500') + '"></span></span>' : '';
      
      var tagClass = 'badge-neutro'; var tagText = c.tag || 'NEUTRO';
      if(tagText === 'VENDITA') tagClass = 'badge-vendita'; else if(tagText === 'TECNICO' || tagText === 'URGENTE') tagClass = 'badge-tecnico'; else if(tagText === 'ORDINE') tagClass = 'badge-ordine';

      var avatarBg = isWA ? 'bg-gradient-to-br from-emerald-400 to-emerald-600' : 'bg-gradient-to-br from-blue-500 to-blue-700';

      htmlContent += '<div onclick="openChatMobile(\\'' + c.phone + '\\')" class="chat-item p-4 border-b border-slate-100 cursor-pointer ' + bgClass + '">';
      htmlContent += '<div class="flex gap-4 items-center"><div class="relative"><div class="w-12 h-12 rounded-full flex items-center justify-center text-white text-base font-bold shadow-sm ' + avatarBg + '">' + (c.name||'?').charAt(0).toUpperCase() + '</div>' + badge + '</div>';
      htmlContent += '<div class="flex-1 min-w-0"><div class="flex justify-between items-center mb-1"><div class="font-bold text-[15px] text-slate-800 truncate">' + (c.name||c.phone) + '</div><div class="text-[11px] text-slate-400 font-semibold shrink-0">' + time + '</div></div>';
      htmlContent += '<div class="flex items-center gap-1.5"><div class="text-[13px] truncate flex-1 ' + (isUnread ? 'font-bold text-slate-800' : 'text-slate-500') + '">' + lastText + '</div></div>';
      htmlContent += '<div class="flex mt-1.5 items-center"><span class="text-[9px] px-1.5 py-0.5 rounded uppercase font-bold tracking-wide ' + tagClass + '">' + tagText + '</span>' + (c.manual ? '<span class="text-[9px] font-bold ml-1.5 px-1.5 py-0.5 rounded bg-slate-200 text-slate-600">\u{1F464} STAFF</span>' : '') + '</div></div></div></div>';
    });

    document.getElementById('chatList').innerHTML = htmlContent;

  } catch(e) {}
}

function renderM(p) { 
  try {
    var c = chats.find(x => x.phone === p); 
    if(!c) return; 
    
    document.getElementById('empty').classList.add('hidden');
    ['chatH','msgA','compWrapper'].forEach(id => document.getElementById(id).classList.remove('hidden'));
    
    if (c.messages && c.messages.length > 0) { localStorage.setItem('read_' + p, c.messages[c.messages.length-1].timestamp); renderL(); }

    currentManual = c.manual;
    document.getElementById('hAvatar').innerText = (c.name||'?').charAt(0).toUpperCase();
    document.getElementById('hAvatar').className = c.channel === 'web' ? 'w-12 h-12 rounded-full flex items-center justify-center font-bold text-white text-lg shadow-md shrink-0 bg-gradient-to-br from-blue-500 to-blue-700' : 'w-12 h-12 rounded-full flex items-center justify-center font-bold text-white text-lg shadow-md shrink-0 bg-gradient-to-br from-emerald-400 to-emerald-600';
    document.getElementById('hName').innerText = c.name || c.phone;
    
    var hBadge = document.getElementById('hTagBadge');
    var tagText = c.tag || 'NEUTRO';
    hBadge.innerText = tagText;
    hBadge.className = "text-[9px] font-bold px-1.5 py-0.5 rounded uppercase hidden md:block ";
    if (tagText === 'VENDITA') hBadge.classList.add('badge-vendita'); else if (tagText === 'TECNICO' || tagText === 'URGENTE') hBadge.classList.add('badge-tecnico'); else if (tagText === 'ORDINE') hBadge.classList.add('badge-ordine'); else hBadge.classList.add('badge-neutro');

    var lastTime = c.messages.length && c.messages[c.messages.length-1].timestamp ? new Date(c.messages[c.messages.length-1].timestamp).toLocaleTimeString('it-IT', {hour:'2-digit', minute:'2-digit'}) : '';
    document.getElementById('hDetails').innerText = (c.email ? c.email + ' \u2022 ' : '') + (c.channel==='whatsapp' ? '+'+c.phone : 'Sito Web') + ' \u2022 ' + lastTime;
    
    isWhatsApp24hExpired = false; var waNotice = document.getElementById('waNotice'); var msgInput = document.getElementById('msgI');
    if (c.channel === 'whatsapp' && c.lastUserInteraction) { if (Date.now() - c.lastUserInteraction > 86400000) { isWhatsApp24hExpired = true; } }
    
    if (isWhatsApp24hExpired) { waNotice.classList.remove('hidden'); waNotice.classList.add('flex'); msgInput.disabled = true; msgInput.placeholder = "Scegli un template dal menu in alto..."; } 
    else { waNotice.classList.add('hidden'); waNotice.classList.remove('flex'); msgInput.disabled = false; msgInput.placeholder = "Scrivi una risposta..."; }

    var tb = document.getElementById('toggleBtn'); var rb = document.getElementById('resolveBtn');
    if(c.manual) { 
      tb.innerHTML = "<span class='hidden md:inline'>\u{1F468}\u200D\u{1F527} Torna a IA</span><span class='md:hidden'>\u{1F468}\u200D\u{1F527} IA</span>"; tb.className = "p-2 md:px-4 md:py-2 rounded-xl text-xs font-bold text-slate-700 bg-white border border-slate-300 hover:bg-slate-50 transition"; rb.classList.remove('hidden');
    } else { 
      tb.innerHTML = "<span class='hidden md:inline'>\u{1F916} Prendi Controllo</span><span class='md:hidden'>\u{1F916} Staff</span>"; tb.className = "p-2 md:px-4 md:py-2 rounded-xl text-xs font-bold text-white bg-slate-800 hover:bg-slate-700 transition shadow-sm"; rb.classList.add('hidden');
    }

    var html = ''; var msgs = Array.isArray(c.messages) ? c.messages : []; var lastDate = '';
    msgs.forEach(m => { 
      var dObj = m.timestamp ? new Date(m.timestamp) : new Date();
      var dateStr = dObj.toLocaleDateString('it-IT', {weekday:'long', day:'numeric', month:'long'});
      if (dateStr !== lastDate) { html += '<div class="flex justify-center my-4"><span class="bg-slate-100 text-slate-400 text-[10px] px-3 py-1 rounded-full font-bold uppercase tracking-wide">'+dateStr+'</span></div>'; lastDate = dateStr; }

      if (m.from === 'system') { html += '<div class="flex justify-center mb-4 w-full"><div class="msg-system break-words">'+m.text+'</div></div>'; return; }

      var isRight = m.from === 'admin'; var bubbleClass = isRight ? 'msg-admin' : (m.from === 'bot' ? 'msg-bot' : 'msg-user');
      var sender = isRight ? 'Tu' : (m.from === 'bot' ? 'IA SMR' : (c.name || 'Cliente'));
      
      var mediaHtml = '';
      if (m.mediaId) {
        if (m.mediaType === 'image') { mediaHtml = '<a href="/api/media/' + m.mediaId + '" target="_blank"><img src="/api/media/' + m.mediaId + '" class="max-w-full md:max-w-[240px] rounded-xl mb-2 shadow-sm border border-slate-200 hover:opacity-90 transition"></a>'; } 
        else { mediaHtml = '<a href="/api/media/' + m.mediaId + '" target="_blank" class="flex items-center gap-2 bg-white/60 p-3 rounded-lg text-xs mb-2 font-bold text-blue-700 border border-slate-200 hover:bg-white transition truncate">\u{1F4CE} '+(m.fileName||'Allegato')+'</a>'; }
      }
      html += '<div class="flex flex-col '+(isRight ? 'items-end' : 'items-start')+' mb-4 w-full"><span class="text-[10px] text-slate-400 font-medium mb-1 px-1">'+sender+' \xB7 '+dObj.toLocaleTimeString('it-IT', {hour:'2-digit', minute:'2-digit'})+'</span><div class="msg-bubble '+bubbleClass+'">'+mediaHtml+'<div class="whitespace-pre-wrap">'+(m.text||'')+'</div></div></div>'; 
    }); 
    
    document.getElementById('msgA').innerHTML = html; document.getElementById('msgA').scrollTop = document.getElementById('msgA').scrollHeight; 
  } catch(e) {}
}

function openChatMobile(phone) {
  curr = phone;
  document.body.classList.add('mobile-view-chat');
  fetchChatDetailAndRender(phone);
}

function closeChatMobile() {
  curr = null;
  document.body.classList.remove('mobile-view-chat');
  document.getElementById('empty').classList.remove('hidden');
  ['chatH','msgA','compWrapper'].forEach(id => document.getElementById(id).classList.add('hidden'));
}

function showView(view) { if (view === 'chats') { closeChatMobile(); hideT(); } }
function showT() { document.body.classList.add('mobile-view-chat'); document.getElementById('tZone').classList.remove('hidden'); }
function hideT() { document.getElementById('tZone').classList.add('hidden'); if (window.innerWidth < 768 && !curr) closeChatMobile(); }
function switchTrainTab(type) { currentTrainType = type; document.querySelectorAll('.t-tab').forEach(el => el.classList.remove('active')); document.querySelectorAll('.t-content').forEach(el => el.classList.add('hidden')); document.getElementById('t-tab-'+type).classList.add('active'); document.getElementById('t-content-'+type).classList.remove('hidden'); }
function previewTrainImage() { const file = document.getElementById('tImgFile').files[0]; if (file) { const reader = new FileReader(); reader.onload = function(e) { document.getElementById('tImgPreview').src = e.target.result; document.getElementById('tImgPreview').classList.remove('hidden'); document.getElementById('tImgBase64').value = e.target.result; }; reader.readAsDataURL(file); } }

async function saveOmni() {
    const btn = document.getElementById('tBtn'); let payload = { source: "SMR Vault Admin" };
    if (currentTrainType === 'text') { payload.type = 'text'; payload.content = document.getElementById('tText').value.trim(); if(!payload.content) return alert("Inserisci il testo."); } 
    else if (currentTrainType === 'link') { payload.type = 'url'; payload.content = document.getElementById('tLink').value.trim(); if(!payload.content) return alert("Inserisci il link."); } 
    else if (currentTrainType === 'img') { payload.type = 'image'; payload.content = document.getElementById('tImgBase64').value; if(!payload.content) return alert("Carica un'immagine."); }
    btn.innerText = "\u23F3 Memorizzazione..."; btn.disabled = true;
    try { const res = await fetch('/api/ingest', { method: 'POST', body: JSON.stringify(payload) }); const data = await res.json(); if (res.ok) { showToast("Dati acquisiti nel Vault!"); document.getElementById('tText').value = ''; document.getElementById('tLink').value = ''; document.getElementById('tImgFile').value = ''; document.getElementById('tImgPreview').classList.add('hidden'); hideT(); } else { alert("\u274C Errore: " + data.error); } } catch(e) { alert("Errore di rete."); } finally { btn.innerText = "Salva nel Vault"; btn.disabled = false; }
}

async function delChat(){ if (confirm("Cancellare chat?")) { await fetch('/api/delete', {method: 'POST', body: JSON.stringify({phone: curr})}); curr = null; location.reload(); } }
async function toggleM(){ await fetch('/api/toggle', {method: 'POST', body: JSON.stringify({phone: curr, manual: !currentManual})}); load(); }
async function resolveChat(){ await fetch('/api/resolve', {method: 'POST', body: JSON.stringify({phone: curr})}); if (window.innerWidth < 768) closeChatMobile(); else { curr = null; location.reload(); } }
function insertQuick(txt) { document.getElementById('msgI').value = txt; document.getElementById('msgI').focus(); }
function setTab(archived) { viewArchived = archived; document.getElementById('tabOpen').className = archived ? 'tab-btn flex-1 text-center text-sm transition' : 'tab-btn active flex-1 text-center text-sm transition'; document.getElementById('tabArchived').className = archived ? 'tab-btn active flex-1 text-center text-sm transition' : 'tab-btn flex-1 text-center text-sm transition'; renderL(); }
function previewFile() { const file = document.getElementById('adminFile').files[0]; const pv = document.getElementById('filePreview'); if (file) { pv.innerText = file.name; pv.classList.remove('hidden'); pv.classList.add('flex'); } else { pv.classList.add('hidden'); pv.classList.remove('flex'); } }
async function sendNote() { var t = prompt("Inserisci nota segreta:"); if (!t || !curr) return; await fetch('/api/reply', {method: 'POST', body: JSON.stringify({phone: curr, text: t, isNote: true})}); load(); }

document.getElementById('msgI').addEventListener('input', function() { this.style.height = '48px'; this.style.height = (this.scrollHeight) + 'px'; });

document.getElementById('comp').onsubmit = async(e) => { 
  e.preventDefault(); 
  var i = document.getElementById('msgI'); var btn = document.getElementById('sendBtn'); var f = document.getElementById('adminFile').files[0]; var t = i.value.trim(); 
  let payload = { phone: curr, text: t };
  if (isWhatsApp24hExpired) { let tpl = document.getElementById('waTemplateSelect').value; if (!tpl) return alert("Seleziona template (Lim. 24h)."); payload.template = tpl; } 
  else { if (!t && !f) return; }
  if (!curr) return; 
  i.disabled = true; btn.innerHTML = '<svg class="animate-spin h-5 w-5 text-white" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>';
  try {
    if (f && !isWhatsApp24hExpired) {
      const fd = new FormData(); fd.append("file", f);
      const res = await fetch('/api/upload', { method: 'POST', body: fd });
      const data = await res.json();
      payload.mediaUrl = data.url; payload.mediaType = data.type; payload.fileName = data.name;
      document.getElementById('adminFile').value = ""; document.getElementById('filePreview').classList.add('hidden');
    }
    await fetch('/api/reply', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(payload) }); 
  } catch(err) { alert("Errore di invio"); }
  i.value = ''; i.style.height = '48px'; i.disabled = false; btn.innerHTML = '<span class="hidden md:inline">Invia</span><svg class="w-5 h-5 md:hidden" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><line x1="22" y1="2" x2="11" y2="13"></line><polygon points="22 2 15 22 11 13 2 9 22 2"></polygon></svg>'; i.focus(); load(); 
};

document.getElementById('msgI').addEventListener('keydown', function(e) { if (e.key === 'Enter' && !e.shiftKey) { if (window.innerWidth > 768) { e.preventDefault(); document.getElementById('comp').dispatchEvent(new Event('submit')); } } });

setInterval(load, 3000); load();
<\/script></body></html>`;
  }
};
export {
  src_default as default
};
//# sourceMappingURL=index.js.map
