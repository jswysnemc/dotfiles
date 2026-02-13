import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./Theme.js" as Theme

ShellRoot {
    id: root

    // ============ Animation State ============
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelY: 15

    // ============ Position from environment ============
    property string posEnv: Quickshell.env("QS_POS") || "center"
    property int marginT: parseInt(Quickshell.env("QS_MARGIN_T")) || 8
    property int marginR: parseInt(Quickshell.env("QS_MARGIN_R")) || 8
    property int marginB: parseInt(Quickshell.env("QS_MARGIN_B")) || 8
    property int marginL: parseInt(Quickshell.env("QS_MARGIN_L")) || 8
    property bool anchorTop: posEnv.indexOf("top") !== -1
    property bool anchorBottom: posEnv.indexOf("bottom") !== -1
    property bool anchorLeft: posEnv.indexOf("left") !== -1
    property bool anchorRight: posEnv.indexOf("right") !== -1
    property bool anchorVCenter: posEnv === "center-left" || posEnv === "center" || posEnv === "center-right"
    property bool anchorHCenter: posEnv === "top-center" || posEnv === "center" || posEnv === "bottom-center"

    // ============ State ============
    property var clipboardItems: []
    property var filteredItems: []
    property string searchText: ""
    property var activeTagFilters: []
    property bool showTagFilters: false
    property var tagCounts: ({})
    property var itemIndexById: ({})
    property int selectedIndex: 0
    property bool loading: false
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-clipboard"
    readonly property int clipboardListLimit: parseInt(Quickshell.env("QS_CLIPBOARD_LIST_LIMIT")) || 220
    readonly property int decodeChunkSize: parseInt(Quickshell.env("QS_CLIPBOARD_DECODE_CHUNK")) || 24
    readonly property var tagFilterOptions: [
        ({ id: "text", label: "文本", icon: "\uf0f6" }),
        ({ id: "code", label: "代码", icon: "\uf121" }),
        ({ id: "url", label: "链接", icon: "\uf0c1" }),
        ({ id: "image", label: "图片", icon: "\uf03e" }),
        ({ id: "file", label: "文件", icon: "\uf15b" }),
        ({ id: "video", label: "视频", icon: "\uf03d" }),
        ({ id: "html", label: "HTML", icon: "\uf13b" }),
        ({ id: "color", label: "颜色", icon: "\uf53f" })
    ]
    readonly property var tagAliasMap: ({
        "text": "text",
        "文本": "text",
        "code": "code",
        "代码": "code",
        "url": "url",
        "链接": "url",
        "link": "url",
        "path": "path",
        "路径": "path",
        "image": "image",
        "img": "image",
        "图片": "image",
        "图像": "image",
        "gif": "gif",
        "video": "video",
        "视频": "video",
        "audio": "audio",
        "音频": "audio",
        "file": "file",
        "文件": "file",
        "document": "document",
        "doc": "document",
        "文档": "document",
        "archive": "archive",
        "压缩包": "archive",
        "压缩": "archive",
        "html": "html",
        "网页": "html",
        "color": "color",
        "颜色": "color"
    })

    // Preview state
    property bool previewVisible: false
    property var previewItem: null
    property string previewFullText: ""
    // Re-parsed file paths from decoded content (for preview overlay)
    property var previewFilePaths: {
        if (!previewItem || !previewItem.isFile || !previewFullText) return previewItem ? previewItem.filePaths : []
        var paths = extractFilePaths(previewFullText)
        return paths.length > 0 ? paths : (previewItem ? previewItem.filePaths : [])
    }

    // ============ Clipboard Loading ============
    property string clipboardBuffer: ""
    property string asyncDecodeBuffer: ""
    property string mimeProbeBuffer: ""
    property bool mimeProbePending: false
    property var pathMimeCache: ({})
    property var mimeProbeTasks: ({})
    property int mimeProbeSeq: 0
    property var pendingDecodeIds: []
    property int pendingDecodeCursor: 0

    Process {
        id: loadClipboard
        command: ["bash", "-lc", "cliphist list | head -n " + root.clipboardListLimit]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root.clipboardBuffer += data
            }
        }
        onExited: code => {
            if (code === 0) {
                try {
                    root.parseClipboardData(root.clipboardBuffer)
                } catch (e) {
                    console.error("parseClipboardData error:", e)
                }
            }
            root.clipboardBuffer = ""
            root.loading = false
        }
    }

    Process {
        id: asyncDecodeProcess
        command: ["echo"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root.asyncDecodeBuffer += data
            }
        }
        onExited: code => {
            if (code === 0 && root.asyncDecodeBuffer) {
                root.updateDecodedEntries(root.asyncDecodeBuffer)
            }
            root.asyncDecodeBuffer = ""
            if (root.pendingDecodeCursor < root.pendingDecodeIds.length) {
                decodeChunkTimer.restart()
            }
        }
    }

    Process {
        id: mimeProbeProcess
        command: ["echo"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root.mimeProbeBuffer += data
            }
        }
        onExited: code => {
            if (code === 0 && root.mimeProbeBuffer) {
                root.applyMimeProbeData(root.mimeProbeBuffer)
            }
            root.mimeProbeBuffer = ""
            if (root.mimeProbePending) {
                root.mimeProbePending = false
                root.startMimeProbe()
            }
        }
    }

    function updateDecodedEntries(data) {
        var marker = "===CLIP:"
        var endMarker = "===\n"
        var pos = 0
        var updated = false
        data = sanitizeClipboardText(data)
        while (true) {
            var start = data.indexOf(marker, pos)
            if (start === -1) break
            var idStart = start + marker.length
            var idEnd = data.indexOf(endMarker, idStart)
            if (idEnd === -1) break
            var id = data.substring(idStart, idEnd)
            var contentStart = idEnd + endMarker.length
            var nextMarker = data.indexOf(marker, contentStart)
            var content = nextMarker === -1 ? data.substring(contentStart) : data.substring(contentStart, nextMarker)

            var idx = root.itemIndexById[String(id)]
            if (idx !== undefined) {
                var item = clipboardItems[idx]
                var itemChanged = false

                if (item.textType === "html") {
                    var srcs = extractHtmlImageSrcs(content)
                    if (srcs.length > 0) {
                        var nextPreview = srcs.map(function(s) {
                            if (s.startsWith("data:")) return "[base64 image]"
                            return s.split("/").pop()
                        }).join(", ")
                        if (JSON.stringify(item.htmlImageSrcs || []) !== JSON.stringify(srcs)) {
                            item.htmlImageSrcs = srcs
                            updated = true
                            itemChanged = true
                        }
                        if (item.preview !== nextPreview) {
                            item.preview = nextPreview
                            updated = true
                            itemChanged = true
                        }
                        if (item.htmlPlainText) {
                            item.htmlPlainText = ""
                            updated = true
                            itemChanged = true
                        }
                        if (item.htmlPreferPlain) {
                            item.htmlPreferPlain = false
                            updated = true
                            itemChanged = true
                        }
                    } else {
                        if (item.htmlImageSrcs && item.htmlImageSrcs.length > 0) {
                            item.htmlImageSrcs = []
                            updated = true
                            itemChanged = true
                        }
                        var plain = htmlToPlainText(content)
                        var preferPlain = shouldTreatHtmlAsPlainText(content, plain)
                        if (item.htmlPlainText !== plain) {
                            item.htmlPlainText = plain
                            updated = true
                            itemChanged = true
                        }
                        if (item.htmlPreferPlain !== preferPlain) {
                            item.htmlPreferPlain = preferPlain
                            updated = true
                            itemChanged = true
                        }
                        if (preferPlain && plain) {
                            var plainPreview = previewText(plain)
                            if (item.preview !== plainPreview) {
                                item.preview = plainPreview
                                updated = true
                                itemChanged = true
                            }
                        }
                    }
                } else if (item.isFile) {
                    var paths = extractFilePaths(content)
                    if (paths.length > 0) {
                        var nextType = classifyFile(paths[0])
                        var nextPreview2 = paths.map(function(p) {
                            return p.split("/").pop()
                        }).join(", ")
                        if (JSON.stringify(item.filePaths || []) !== JSON.stringify(paths)) {
                            item.filePaths = paths
                            updated = true
                            itemChanged = true
                        }
                        if (item.fileType !== nextType) {
                            item.fileType = nextType
                            updated = true
                            itemChanged = true
                        }
                        if (item.preview !== nextPreview2) {
                            item.preview = nextPreview2
                            updated = true
                            itemChanged = true
                        }
                    }
                }

                if (itemChanged) {
                    rebuildItemDerivedFields(item)
                }
            }
            pos = nextMarker === -1 ? data.length : nextMarker
        }
        if (updated) {
            clipboardItems = clipboardItems.slice()
            rebuildTagCounts()
            filterItems()
            queueMimeProbe()
        }
    }

    function shellQuote(str) {
        return "'" + String(str === undefined || str === null ? "" : str).replace(/'/g, "'\"'\"'") + "'"
    }

    function normalizeLocalPath(path) {
        var p = String(path === undefined || path === null ? "" : path)
        if (!p) return ""
        if (p.startsWith("file://localhost/")) {
            p = "/" + p.substring("file://localhost/".length)
        } else if (p.startsWith("file:///")) {
            p = p.substring("file://".length)
        } else if (p.startsWith("file://")) {
            p = p.substring("file://".length)
        }
        try { p = decodeURIComponent(p) } catch (e) {}
        return p
    }

    function sanitizeClipboardText(text) {
        var s = String(text === undefined || text === null ? "" : text)
        s = s.replace(/\u0000/g, "")
        s = s.replace(/\r/g, "")
        return s
    }

    function previewText(text) {
        return sanitizeClipboardText(text).substring(0, 200).replace(/\n/g, " ").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    function pushUnique(list, value) {
        if (!value) return
        if (list.indexOf(value) === -1) list.push(value)
    }

    function normalizeTag(tag) {
        var normalized = String(tag === undefined || tag === null ? "" : tag).trim().toLowerCase()
        normalized = normalized.replace(/^#+/, "")
        if (!normalized) return ""
        return root.tagAliasMap[normalized] || normalized
    }

    function parseSearchQuery(text) {
        var src = String(text === undefined || text === null ? "" : text)
        var tagTokens = src.match(/#([^\s#]+)/g) || []
        var tags = []
        for (var i = 0; i < tagTokens.length; i++) {
            var nextTag = normalizeTag(tagTokens[i].substring(1))
            if (nextTag) pushUnique(tags, nextTag)
        }
        var keyword = src.replace(/#([^\s#]+)/g, " ").replace(/\s+/g, " ").trim().toLowerCase()
        return {
            keyword: keyword,
            tags: tags
        }
    }

    function mergeFilterTags(searchTags) {
        var merged = activeTagFilters.slice()
        for (var i = 0; i < searchTags.length; i++) {
            pushUnique(merged, searchTags[i])
        }
        return merged
    }

    function hasAllTags(item, requiredTags) {
        if (!requiredTags || requiredTags.length === 0) return true
        var set = item.tagSet || {}
        for (var i = 0; i < requiredTags.length; i++) {
            if (!set[requiredTags[i]]) return false
        }
        return true
    }

    function buildItemTags(item) {
        var tags = []

        if (item.isImage) {
            pushUnique(tags, "image")
            if (String(item.imageExt || "").toLowerCase() === "gif") pushUnique(tags, "gif")
        } else if (item.isFile) {
            pushUnique(tags, "file")
            if (item.fileType) pushUnique(tags, item.fileType)
            if (item.filePaths && item.filePaths.length > 1) pushUnique(tags, "multi")
        } else {
            pushUnique(tags, "text")
            if (item.textType) pushUnique(tags, item.textType)
        }

        if (item.textType === "html" && item.htmlImageSrcs && item.htmlImageSrcs.length > 0) {
            pushUnique(tags, "image")
            pushUnique(tags, "html")
        }

        return tags
    }

    function rebuildItemDerivedFields(item) {
        var tags = buildItemTags(item)
        var tagSet = {}
        for (var i = 0; i < tags.length; i++) {
            tagSet[tags[i]] = true
        }

        var searchParts = []
        searchParts.push(item.preview || "")
        if (item.filePaths && item.filePaths.length > 0) searchParts.push(item.filePaths.join(" "))
        if (item.textType === "html" && item.htmlPlainText) searchParts.push(item.htmlPlainText)
        searchParts.push(tags.join(" "))
        if (item.isImage && item.imageExt) searchParts.push(item.imageExt)

        item.tags = tags
        item.tagSet = tagSet
        item.searchBlobLower = sanitizeClipboardText(searchParts.join(" ")).toLowerCase()
        item.hasVisualPreview = item.isImage
            || (item.isFile && (item.fileType === "image" || item.fileType === "gif" || item.fileType === "video"))
            || (item.textType === "html" && item.htmlImageSrcs && item.htmlImageSrcs.length > 0 && isLocalImagePath(item.htmlImageSrcs[0]))
    }

    function rebuildItemIndexMap() {
        var map = {}
        for (var i = 0; i < clipboardItems.length; i++) {
            map[String(clipboardItems[i].id)] = i
        }
        itemIndexById = map
    }

    function rebuildTagCounts() {
        var counts = {}
        for (var i = 0; i < clipboardItems.length; i++) {
            var tags = clipboardItems[i].tags || []
            for (var j = 0; j < tags.length; j++) {
                var tag = tags[j]
                counts[tag] = (counts[tag] || 0) + 1
            }
        }
        tagCounts = counts
    }

    function tagCount(tag) {
        return tagCounts[tag] || 0
    }

    function toggleTagFilter(tag) {
        var normalized = normalizeTag(tag)
        if (!normalized) return
        var next = activeTagFilters.slice()
        var idx = next.indexOf(normalized)
        if (idx !== -1) next.splice(idx, 1)
        else next.push(normalized)
        activeTagFilters = next
    }

    function clearTagFilters() {
        activeTagFilters = []
    }

    function queueAsyncDecode(ids) {
        pendingDecodeIds = ids ? ids.slice() : []
        pendingDecodeCursor = 0
        if (pendingDecodeIds.length > 0) {
            decodeChunkTimer.restart()
        }
    }

    function runNextDecodeChunk() {
        if (asyncDecodeProcess.running) return
        if (!pendingDecodeIds || pendingDecodeCursor >= pendingDecodeIds.length) return

        var end = Math.min(pendingDecodeCursor + decodeChunkSize, pendingDecodeIds.length)
        var chunk = pendingDecodeIds.slice(pendingDecodeCursor, end)
        pendingDecodeCursor = end

        if (chunk.length === 0) return
        var cmd = chunk.map(function(id) {
            return "printf '===CLIP:" + id + "===\\n'; cliphist decode '" + id + "'"
        }).join("; ")
        asyncDecodeProcess.command = ["bash", "-c", cmd]
        asyncDecodeProcess.running = true
    }

    function isLikelyBinaryNoiseText(content) {
        var raw = String(content === undefined || content === null ? "" : content)
        if (raw.indexOf("\u0000") !== -1) return true
        var s = sanitizeClipboardText(raw)
        if (!s) return false
        var probe = s
        if (probe.startsWith("copy ")) probe = probe.substring(5)
        if (probe.startsWith("cut ")) probe = probe.substring(4)

        if (/IHDR/.test(probe) && /IDAT/.test(probe)) return true
        if (/^\u001A\s*\u0000{2,}/.test(probe)) return true

        var limit = Math.min(probe.length, 280)
        var ctrl = 0
        var repl = 0
        for (var i = 0; i < limit; i++) {
            var c = probe.charCodeAt(i)
            if (probe.charAt(i) === "\uFFFD") repl++
            if (c === 9 || c === 10 || c === 13) continue
            if (c < 32 || c === 127) ctrl++
        }

        if (repl >= 4 && (probe.indexOf("IHDR") !== -1 || probe.indexOf("IDAT") !== -1)) return true
        return limit > 24 && (ctrl / limit) > 0.08
    }

    function queueMimeProbe() {
        if (mimeProbeProcess.running) {
            mimeProbePending = true
            return
        }
        startMimeProbe()
    }

    function startMimeProbe() {
        var tasks = {}
        var parts = []
        var taskCount = 0
        var maxTasks = 512
        var queuedPaths = {}

        function addTask(kind, id, rawPath) {
            if (taskCount >= maxTasks) return
            var path = normalizeLocalPath(rawPath)
            if (!path || path.charAt(0) !== "/") return
            if (queuedPaths[path]) return
            if (root.pathMimeCache[path] !== undefined) return
            var token = String(++root.mimeProbeSeq)
            tasks[token] = { kind: kind, id: String(id), path: path }
            parts.push('printf "===MIME:' + token + '===\\n"; file -Lb --mime-type -- ' + shellQuote(path) + ' 2>/dev/null || true')
            queuedPaths[path] = true
            taskCount++
        }

        for (var i = 0; i < clipboardItems.length; i++) {
            var item = clipboardItems[i]
            if (item.isFile && item.filePaths && item.filePaths.length > 0) {
                for (var f = 0; f < item.filePaths.length; f++) {
                    addTask("FILE", item.id, item.filePaths[f])
                }
            }
            if (item.textType === "html" && item.htmlImageSrcs && item.htmlImageSrcs.length > 0) {
                for (var s = 0; s < item.htmlImageSrcs.length; s++) {
                    addTask("HTML", item.id, item.htmlImageSrcs[s])
                }
            }
        }

        if (parts.length === 0) return

        root.mimeProbeTasks = tasks
        root.mimeProbeBuffer = ""
        mimeProbeProcess.command = ["bash", "-c", parts.join("; ")]
        mimeProbeProcess.running = true
    }

    function applyMimeProbeData(data) {
        var marker = "===MIME:"
        var endMarker = "===\n"
        var pos = 0
        var updated = false
        var newCache = Object.assign({}, root.pathMimeCache)

        while (true) {
            var start = data.indexOf(marker, pos)
            if (start === -1) break
            var tokenStart = start + marker.length
            var tokenEnd = data.indexOf(endMarker, tokenStart)
            if (tokenEnd === -1) break

            var token = data.substring(tokenStart, tokenEnd)
            var contentStart = tokenEnd + endMarker.length
            var nextMarker = data.indexOf(marker, contentStart)
            var content = nextMarker === -1 ? data.substring(contentStart) : data.substring(contentStart, nextMarker)
            var mime = content.trim().split(/\s+/)[0]
            var task = root.mimeProbeTasks[token]

            if (task && mime) {
                var prevMime = newCache[task.path] || ""
                newCache[task.path] = mime
                if (prevMime !== mime) updated = true

                var idx = root.itemIndexById[task.id]
                if (idx !== undefined) {
                    var item = clipboardItems[idx]
                    var itemChanged = false
                    if (task.kind === "FILE" && item.isFile && item.filePaths && item.filePaths.length > 0) {
                        var firstPath = normalizeLocalPath(item.filePaths[0])
                        var firstMime = firstPath ? (newCache[firstPath] || "") : ""
                        var nextType = firstMime ? classifyFileByMime(firstMime, firstPath || item.filePaths[0]) : classifyFileByExt(firstPath || item.filePaths[0])
                        if (item.fileMime !== firstMime) {
                            item.fileMime = firstMime
                            updated = true
                            itemChanged = true
                        }
                        if (item.fileType !== nextType) {
                            item.fileType = nextType
                            updated = true
                            itemChanged = true
                        }
                    } else if (task.kind === "HTML" && item.textType === "html") {
                        if (item.htmlImageMime !== mime) {
                            item.htmlImageMime = mime
                            updated = true
                        }
                    }
                    if (itemChanged) rebuildItemDerivedFields(item)
                }
            }

            pos = nextMarker === -1 ? data.length : nextMarker
        }

        root.pathMimeCache = newCache
        if (updated) {
            clipboardItems = clipboardItems.slice()
            rebuildTagCounts()
            filterItems()
            if (clipboardItems.some(function(i) { return i.isFile && i.fileType === "video" })) {
                startVideoThumbGen()
            }
        }
    }

    // ============ Type Classification ============
    readonly property var imageExts: ["png", "jpg", "jpeg", "webp", "bmp", "tiff", "tif", "ico", "svg"]
    readonly property var gifExts: ["gif"]
    readonly property var videoExts: ["mp4", "mkv", "webm", "avi", "mov", "flv", "wmv", "m4v", "ts", "mpg", "mpeg"]
    readonly property var audioExts: ["mp3", "flac", "wav", "ogg", "m4a", "aac", "wma", "opus"]
    readonly property var archiveExts: ["zip", "tar", "gz", "bz2", "xz", "7z", "rar", "zst"]
    readonly property var docExts: ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp", "txt", "md", "csv"]

    function classifyFileByExt(path) {
        var ext = path.split(".").pop().toLowerCase()
        if (gifExts.indexOf(ext) !== -1) return "gif"
        if (imageExts.indexOf(ext) !== -1) return "image"
        if (videoExts.indexOf(ext) !== -1) return "video"
        if (audioExts.indexOf(ext) !== -1) return "audio"
        if (archiveExts.indexOf(ext) !== -1) return "archive"
        if (docExts.indexOf(ext) !== -1) return "document"
        return "other"
    }

    function classifyFileByMime(mime, path) {
        var m = String(mime === undefined || mime === null ? "" : mime).toLowerCase()
        if (m === "image/gif") return "gif"
        if (m.startsWith("image/")) return "image"
        if (m.startsWith("video/")) return "video"
        if (m.startsWith("audio/")) return "audio"
        if (m.indexOf("zip") !== -1 || m.indexOf("compressed") !== -1 || m === "application/x-tar") return "archive"
        if (m.startsWith("text/") || m === "application/pdf" || m.indexOf("document") !== -1 || m.indexOf("sheet") !== -1 || m.indexOf("presentation") !== -1) return "document"
        return classifyFileByExt(path)
    }

    function classifyFile(path) {
        var normalized = normalizeLocalPath(path)
        var mime = normalized ? (root.pathMimeCache[normalized] || "") : ""
        if (mime) return classifyFileByMime(mime, normalized || path)
        return classifyFileByExt(normalized || path)
    }

    // Classify text content type
    function classifyText(content) {
        var trimmed = content.trim()
        // HTML (from QQ, browsers, etc.)
        if (/<\s*(img|html|body|div|span|p|meta|table)\b/i.test(trimmed)) return "html"
        // URL
        if (/^https?:\/\/\S+$/i.test(trimmed)) return "url"
        // Multi-line URL list
        if (trimmed.split("\n").every(function(l) { return /^https?:\/\/\S+$/i.test(l.trim()) || l.trim() === "" })) {
            if (trimmed.indexOf("http") !== -1) return "url"
        }
        // Path
        if (/^(\/[\w.\-]+)+\/?$/.test(trimmed)) return "path"
        // Color hex
        if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(trimmed)) return "color"
        // Code-like (has braces, semicolons, function keywords)
        var codeScore = 0
        if (trimmed.indexOf("{") !== -1 && trimmed.indexOf("}") !== -1) codeScore++
        if (/;\s*$/.test(trimmed) || /;\s*\n/.test(trimmed)) codeScore++
        if (/\b(function|const|let|var|import|def|class|return|if|for|while)\b/.test(trimmed)) codeScore++
        if (/[=!<>]{2,}/.test(trimmed)) codeScore++
        if (codeScore >= 2) return "code"
        return "text"
    }

    // Extract image sources from HTML content (QQ, browsers, etc.)
    // Returns array of local file paths or remote URLs
    function extractHtmlImageSrcs(html) {
        var srcs = []
        var re = /<img[^>]+src\s*=\s*["']([^"']+)["']/gi
        var match
        while ((match = re.exec(html)) !== null) {
            var src = match[1]
            if (src.startsWith("file://")) {
                srcs.push(src)
            } else if (src.startsWith("/")) {
                srcs.push(src)
            } else if (src.startsWith("data:image/")) {
                srcs.push(src)  // base64 data URI
            } else if (/^https?:\/\//i.test(src)) {
                srcs.push(src)  // remote URL
            }
        }
        return srcs
    }

    function decodeHtmlEntities(text) {
        var s = String(text === undefined || text === null ? "" : text)
        s = s
            .replace(/&nbsp;/gi, " ")
            .replace(/&lt;/gi, "<")
            .replace(/&gt;/gi, ">")
            .replace(/&amp;/gi, "&")
            .replace(/&quot;/gi, "\"")
            .replace(/&apos;/gi, "'")
            .replace(/&#39;/g, "'")

        s = s.replace(/&#x([0-9a-fA-F]+);/g, function(_, hex) {
            var code = parseInt(hex, 16)
            if (!isFinite(code) || code <= 0) return ""
            if (String.fromCodePoint) return String.fromCodePoint(code)
            return code <= 0xFFFF ? String.fromCharCode(code) : "\uFFFD"
        })
        s = s.replace(/&#([0-9]+);/g, function(_, dec) {
            var code = parseInt(dec, 10)
            if (!isFinite(code) || code <= 0) return ""
            if (String.fromCodePoint) return String.fromCodePoint(code)
            return code <= 0xFFFF ? String.fromCharCode(code) : "\uFFFD"
        })
        return s
    }

    function htmlToPlainText(html) {
        var s = sanitizeClipboardText(html)
        s = s.replace(/<\s*(script|style)\b[^>]*>[\s\S]*?<\s*\/\s*\1\s*>/gi, " ")
        s = s.replace(/<\s*br\s*\/?>/gi, "\n")
        s = s.replace(/<\s*\/\s*(p|div|li|tr|h[1-6])\s*>/gi, "\n")
        s = s.replace(/<\s*(p|div|li|tr|h[1-6])\b[^>]*>/gi, "\n")
        s = s.replace(/<[^>]*>/g, "")
        s = decodeHtmlEntities(s)
        s = s.replace(/\u00A0/g, " ")
        s = s.replace(/[ \t]+\n/g, "\n").replace(/\n[ \t]+/g, "\n")
        s = s.replace(/[ \t]{2,}/g, " ")
        s = s.replace(/\n{3,}/g, "\n\n")
        return s.trim()
    }

    function shouldTreatHtmlAsPlainText(html, plainText) {
        var s = sanitizeClipboardText(html).trim()
        if (!s) return false
        if (!/<\s*[a-z!/]/i.test(s)) return false
        if (/<\s*(img|svg|video|audio|canvas|iframe|object|embed|table|ul|ol|pre|code|blockquote)\b/i.test(s)) return false
        if (/<\s*a\b[^>]*\bhref\s*=/i.test(s)) return false

        var allowed = {
            "html": true, "body": true, "span": true, "font": true,
            "b": true, "strong": true, "i": true, "em": true,
            "u": true, "s": true, "strike": true, "sub": true, "sup": true,
            "br": true, "p": true, "div": true
        }
        var tagRe = /<\s*\/?\s*([a-zA-Z0-9:-]+)/g
        var m
        while ((m = tagRe.exec(s)) !== null) {
            var tag = String(m[1] || "").toLowerCase()
            if (!tag || tag.charAt(0) === "!") continue
            if (!allowed[tag]) return false
        }

        var plain = String(plainText === undefined || plainText === null ? htmlToPlainText(s) : plainText).trim()
        if (!plain) return false
        var visible = decodeHtmlEntities(s.replace(/<[^>]*>/g, "")).replace(/\s+/g, "")
        if (!visible) return false
        return true
    }

    // Check if a path is a local previewable image
    function isLocalImagePath(path) {
        var src = String(path === undefined || path === null ? "" : path)
        if (!src || src.startsWith("data:") || /^https?:\/\//i.test(src)) return false
        var normalized = normalizeLocalPath(src)
        if (!normalized || normalized.charAt(0) !== "/") return false
        var mime = root.pathMimeCache[normalized] || ""
        if (!mime) return true
        return mime.startsWith("image/")
    }

    function isLocalAnimatedImagePath(path) {
        var normalized = normalizeLocalPath(path)
        if (!normalized || normalized.charAt(0) !== "/") return false
        var mime = root.pathMimeCache[normalized] || ""
        return mime === "image/gif" || mime === "image/apng" || mime === "image/webp"
    }

    function localFileUrl(path) {
        var normalized = normalizeLocalPath(path)
        if (!normalized || normalized.charAt(0) !== "/") return ""
        return "file://" + normalized
    }

    function normalizeBinaryExt(ext) {
        var e = (ext || "").toLowerCase()
        if (e === "jpg") return "jpeg"
        if (e === "tif") return "tiff"
        if (e === "svg+xml") return "svg"
        return e
    }

    function binaryExtFromMeta(content) {
        var m = content.match(/^\[\[\s*binary data\s+.+?\s+([A-Za-z0-9.+\/-]+)\s+[0-9]+x[0-9]+\s*\]\]$/)
        if (!m) return "png"
        var raw = m[1]
        var slash = raw.indexOf("/")
        if (slash !== -1) raw = raw.substring(slash + 1)
        var e = normalizeBinaryExt(raw)
        return e || "png"
    }

    function binaryDimensionsFromMeta(content) {
        var m = content.match(/(\d+)x(\d+)\s*\]\]$/)
        if (m) return m[1] + " x " + m[2]
        return ""
    }

    function binarySizeFromMeta(content) {
        var m = content.match(/binary data\s+(\d+)\s/)
        if (m) {
            var bytes = parseInt(m[1])
            if (bytes > 1048576) return (bytes / 1048576).toFixed(1) + " MB"
            if (bytes > 1024) return (bytes / 1024).toFixed(1) + " KB"
            return bytes + " B"
        }
        return ""
    }

    function imagePathById(id) {
        return root.imagePaths[id] ? root.imagePaths[id] : (cacheDir + "/" + id + ".png")
    }

    function placeholderImageMime(textValue) {
        var m = String(textValue === undefined || textValue === null ? "" : textValue).trim().match(/^\[Binary Image:\s*(image\/[A-Za-z0-9.+-]+)\]$/i)
        return m ? m[1].toLowerCase() : ""
    }

    function extractFilePaths(content) {
        var paths = []
        var src = sanitizeClipboardText(content)
        var re = /file:\/\/([^\s]+)/g
        var match
        while ((match = re.exec(src)) !== null) {
            try {
                var p = decodeURIComponent(match[1])
            } catch (e) {
                var p = match[1]
            }
            p = String(p || "").replace(/\uFFFD/g, "").replace(/[\u0000-\u001F\u007F]/g, "")
            if (p.startsWith("localhost/")) p = "/" + p.substring("localhost/".length)
            if (!p || p.charAt(0) !== "/") continue
            if (paths.indexOf(p) === -1) paths.push(p)
        }
        return paths
    }

    // Type badge info: { label, icon, color }
    function typeBadgeInfo(item) {
        if (item.isImage) {
            var ext = (item.imageExt || "png").toUpperCase()
            if (ext === "GIF") return { label: "GIF", icon: "\uf03e", color: Theme.primary }
            return { label: "IMG", icon: "\uf03e", color: Theme.primary }
        }
        if (item.isFile) {
            if (item.filePaths.length > 1) {
                return { label: item.filePaths.length + "F", icon: "\uf0c5", color: Theme.tertiary }
            }
            switch (item.fileType) {
                case "gif": return { label: "GIF", icon: "\uf03e", color: Theme.primary }
                case "image": return { label: "IMG", icon: "\uf03e", color: Theme.primary }
                case "video": return { label: "VID", icon: "\uf03d", color: "#e67e22" }
                case "audio": return { label: "AUD", icon: "\uf001", color: "#9b59b6" }
                case "archive": return { label: "ZIP", icon: "\uf1c6", color: "#f39c12" }
                case "document": return { label: "DOC", icon: "\uf15c", color: Theme.tertiary }
                default: return { label: "FILE", icon: "\uf15b", color: Theme.tertiary }
            }
        }
        // Text subtypes
        switch (item.textType) {
            case "html":
                if (item.htmlPreferPlain) return { label: "TEXT", icon: "\uf0f6", color: Theme.secondary }
                return { label: "HTML", icon: "\uf13b", color: "#e44d26" }
            case "url": return { label: "URL", icon: "\uf0c1", color: "#2980b9" }
            case "path": return { label: "PATH", icon: "\uf07b", color: "#27ae60" }
            case "color": return { label: "CLR", icon: "\uf53f", color: Theme.primary }
            case "code": return { label: "CODE", icon: "\uf121", color: "#e74c3c" }
            default: return { label: "TEXT", icon: "\uf0f6", color: Theme.secondary }
        }
    }

    // ============ Parse Clipboard Data ============
    function parseClipboardData(data) {
        var rawLines = data.trim().split("\n")
        // Join multi-line entries: cliphist list outputs ID\tcontent,
        // but content may span multiple lines. Lines without a numeric ID+tab
        // prefix are continuation of the previous entry.
        var entries = []
        for (var i = 0; i < rawLines.length; i++) {
            var rl = rawLines[i]
            if (!rl && entries.length === 0) continue
            var ti = rl.indexOf("\t")
            if (ti > 0 && /^\d+$/.test(rl.substring(0, ti))) {
                entries.push({ id: rl.substring(0, ti), content: rl.substring(ti + 1) })
            } else if (entries.length > 0) {
                entries[entries.length - 1].content += "\n" + rl
            }
        }

        var seen = {}
        var items = []
        for (var i = 0; i < entries.length; i++) {
            var id = entries[i].id
            var rawContent = entries[i].content
            var content = sanitizeClipboardText(rawContent)
            var trimmedContent = content.trim()
            var isImage = trimmedContent.startsWith("[[ binary data")
            var isPlaceholderImageText = placeholderImageMime(trimmedContent).length > 0
            if (isPlaceholderImageText) continue

            var imageExt = isImage ? binaryExtFromMeta(trimmedContent) : ""
            var imageDimensions = isImage ? binaryDimensionsFromMeta(trimmedContent) : ""
            var imageSize = isImage ? binarySizeFromMeta(trimmedContent) : ""
            var isFile = !isImage && content.indexOf("file://") !== -1 && !/<\s*(img|html|body|div|span|p|meta|table)\b/i.test(content)

            var filePaths = []
            var fileType = ""
            if (isFile) {
                filePaths = extractFilePaths(content)
                if (filePaths.length === 0) { isFile = false }
                else { fileType = classifyFile(filePaths[0]) }
            }

            var textType = ""
            var htmlImageSrcs = []
            var htmlPlainText = ""
            var htmlPreferPlain = false
            if (!isImage && !isFile) {
                if (isLikelyBinaryNoiseText(rawContent)) continue
                textType = classifyText(content)
                // Extract local image paths from HTML (QQ, browsers, etc.)
                if (textType === "html") {
                    htmlImageSrcs = extractHtmlImageSrcs(content)
                    if (htmlImageSrcs.length === 0) {
                        htmlPlainText = htmlToPlainText(content)
                        htmlPreferPlain = shouldTreatHtmlAsPlainText(content, htmlPlainText)
                    }
                }
            }

            var preview = ""
            if (isImage) {
                var parts = []
                if (imageExt) parts.push(imageExt.toUpperCase())
                if (imageDimensions) parts.push(imageDimensions)
                if (imageSize) parts.push(imageSize)
                preview = parts.length > 0 ? parts.join(" | ") : "image"
            } else if (isFile) {
                preview = filePaths.map(function(p) {
                    return p.split("/").pop()
                }).join(", ")
            } else if (textType === "html" && htmlImageSrcs.length > 0) {
                // Show image file names from HTML
                preview = htmlImageSrcs.map(function(s) {
                    if (s.startsWith("data:")) return "[base64 image]"
                    return s.split("/").pop()
                }).join(", ")
            } else if (textType === "html" && htmlPreferPlain && htmlPlainText) {
                preview = previewText(htmlPlainText)
            } else {
                preview = previewText(content)
            }

            // Deduplicate
            var key = isImage ? ("img:" + content) : (isFile ? ("file:" + filePaths.join("|")) : preview)
            if (seen[key]) continue
            seen[key] = true

            var item = {
                id: id,
                isImage: isImage,
                imageExt: imageExt,
                imageDimensions: imageDimensions,
                imageSize: imageSize,
                isFile: isFile,
                fileType: fileType,
                fileMime: (isFile && filePaths.length > 0) ? (root.pathMimeCache[normalizeLocalPath(filePaths[0])] || "") : "",
                filePaths: filePaths,
                textType: textType,
                htmlImageSrcs: htmlImageSrcs,
                htmlImageMime: "",
                htmlPlainText: htmlPlainText,
                htmlPreferPlain: htmlPreferPlain,
                rawContent: isFile ? content.trim() : "",
                imagePath: "",
                preview: preview,
                colorValue: textType === "color" ? trimmedContent : ""
            }
            rebuildItemDerivedFields(item)
            items.push(item)
        }
        root.clipboardItems = items
        root.rebuildItemIndexMap()
        root.rebuildTagCounts()
        root.filterItems()
        // Decode full content for truncated entries (HTML and multi-file)
        var decodeIds = []
        for (var j = 0; j < items.length; j++) {
            if (items[j].textType === "html" && items[j].htmlImageSrcs.length === 0) {
                decodeIds.push(items[j].id)
            } else if (items[j].isFile) {
                decodeIds.push(items[j].id)
            }
        }
        root.queueAsyncDecode(decodeIds)

        if (items.some(function(i) { return i.isImage })) {
            imageDecodeStartTimer.restart()
        }
        if (items.some(function(i) { return i.isFile && i.fileType === "video" })) {
            videoThumbStartTimer.restart()
        }
        mimeProbeStartTimer.restart()
    }

    // ============ Image Decode ============
    property var imageQueue: []
    property int imageIndex: 0
    property var imagePaths: ({})

    Process {
        id: decodeImage
        property string currentId: ""
        property string currentPath: ""
        command: ["bash", "-c", "echo"]
        onExited: code => {
            if (code === 0 && decodeImage.currentId && decodeImage.currentPath) {
                var newPaths = Object.assign({}, root.imagePaths)
                newPaths[decodeImage.currentId] = decodeImage.currentPath
                root.imagePaths = newPaths
            }
            root.imageIndex++
            root.decodeNextImage()
        }
    }

    function startImageDecode() {
        var ids = []
        for (var i = 0; i < clipboardItems.length; i++) {
            var item = clipboardItems[i]
            if (!item.isImage) continue
            if (root.imagePaths[item.id]) continue
            ids.push(item.id)
        }
        imageQueue = ids
        imageIndex = 0
        if (imageQueue.length > 0) {
            mkCacheDir.running = true
        }
    }

    Process {
        id: mkCacheDir
        command: ["mkdir", "-p", cacheDir]
        onExited: root.decodeNextImage()
    }

    function decodeNextImage() {
        if (imageIndex >= imageQueue.length) return
        var id = imageQueue[imageIndex]
        var ext = "png"
        var idx = root.itemIndexById[String(id)]
        if (idx !== undefined) {
            var item = clipboardItems[idx]
            if (item && item.isImage) ext = item.imageExt || "png"
        }
        decodeImage.currentId = id
        decodeImage.currentPath = cacheDir + "/" + id + "." + ext
        decodeImage.command = ["bash", "-c",
            "cliphist decode '" + id + "' > '" + decodeImage.currentPath + "' 2>/dev/null"
        ]
        decodeImage.running = true
    }

    // ============ Video Thumbnail Generation ============
    property var videoQueue: []
    property int videoIndex: 0
    property var videoThumbPaths: ({})

    Process {
        id: genVideoThumb
        property string currentPath: ""
        command: ["bash", "-c", "echo"]
        onExited: code => {
            if (code === 0 && genVideoThumb.currentPath) {
                var thumbFile = root.cacheDir + "/vthumb_" + Qt.md5(genVideoThumb.currentPath) + ".png"
                var newPaths = Object.assign({}, root.videoThumbPaths)
                newPaths[genVideoThumb.currentPath] = thumbFile
                root.videoThumbPaths = newPaths
            }
            root.videoIndex++
            root.genNextVideoThumb()
        }
    }

    function startVideoThumbGen() {
        var paths = []
        var seen = {}
        for (var i = 0; i < clipboardItems.length; i++) {
            var item = clipboardItems[i]
            if (item.isFile && item.fileType === "video" && item.filePaths.length > 0) {
                var path = item.filePaths[0]
                if (seen[path]) continue
                if (root.videoThumbPaths[path]) continue
                seen[path] = true
                paths.push(path)
            }
        }
        videoQueue = paths
        videoIndex = 0
        if (paths.length > 0) {
            mkCacheDir2.running = true
        }
    }

    Process {
        id: mkCacheDir2
        command: ["mkdir", "-p", cacheDir]
        onExited: root.genNextVideoThumb()
    }

    function genNextVideoThumb() {
        if (videoIndex >= videoQueue.length) return
        var filePath = videoQueue[videoIndex]
        genVideoThumb.currentPath = filePath
        var thumbFile = cacheDir + "/vthumb_" + Qt.md5(filePath) + ".png"
        genVideoThumb.command = ["ffmpegthumbnailer", "-i", filePath, "-o", thumbFile, "-s", "256", "-q", "8"]
        genVideoThumb.running = true
    }

    // ============ Fuzzy Search ============
    function fuzzyMatchLower(pattern, str) {
        if (!pattern) return { match: true, score: 0 }
        var pIdx = 0, sIdx = 0, score = 0, consecutive = 0, lastIdx = -1
        while (pIdx < pattern.length && sIdx < str.length) {
            if (pattern[pIdx] === str[sIdx]) {
                if (lastIdx === sIdx - 1) { consecutive++; score += consecutive * 2 }
                else consecutive = 0
                if (sIdx === 0 || " -_".includes(str[sIdx - 1])) score += 10
                lastIdx = sIdx
                pIdx++
            }
            sIdx++
        }
        if (pIdx === pattern.length) {
            score += Math.max(0, 50 - str.length)
            return { match: true, score: score }
        }
        return { match: false, score: 0 }
    }

    function fuzzyMatch(pattern, str) {
        var p = String(pattern === undefined || pattern === null ? "" : pattern).toLowerCase()
        var s = String(str === undefined || str === null ? "" : str).toLowerCase()
        return fuzzyMatchLower(p, s)
    }

    function filterItems() {
        var parsed = parseSearchQuery(searchText)
        var keyword = parsed.keyword
        var requiredTags = mergeFilterTags(parsed.tags)
        var hasKeyword = keyword.length > 0

        if (!hasKeyword && requiredTags.length === 0) {
            filteredItems = clipboardItems.slice()
        } else {
            var results = []
            for (var i = 0; i < clipboardItems.length; i++) {
                var item = clipboardItems[i]
                if (!hasAllTags(item, requiredTags)) continue

                if (!hasKeyword) {
                    results.push({ item: item, score: 0, originalIndex: i })
                    continue
                }

                var searchTarget = item.searchBlobLower || ""
                var directIdx = searchTarget.indexOf(keyword)
                if (directIdx !== -1) {
                    results.push({ item: item, score: 2000 - directIdx, originalIndex: i })
                    continue
                }

                var m = fuzzyMatchLower(keyword, searchTarget)
                if (m.match) results.push({ item: item, score: m.score, originalIndex: i })
            }

            if (hasKeyword) {
                results.sort(function(a, b) {
                    if (b.score !== a.score) return b.score - a.score
                    return a.originalIndex - b.originalIndex
                })
            }

            filteredItems = results.map(function(r) { return r.item })
        }
        if (filteredItems.length === 0) {
            selectedIndex = 0
        } else if (selectedIndex >= filteredItems.length || selectedIndex < 0) {
            selectedIndex = 0
        }
    }

    Timer {
        id: searchDebounce
        interval: 120
        repeat: false
        onTriggered: root.filterItems()
    }

    Timer {
        id: decodeChunkTimer
        interval: 60
        repeat: false
        onTriggered: root.runNextDecodeChunk()
    }

    Timer {
        id: mimeProbeStartTimer
        interval: 260
        repeat: false
        onTriggered: root.queueMimeProbe()
    }

    Timer {
        id: imageDecodeStartTimer
        interval: 360
        repeat: false
        onTriggered: root.startImageDecode()
    }

    Timer {
        id: videoThumbStartTimer
        interval: 520
        repeat: false
        onTriggered: root.startVideoThumbGen()
    }

    onSearchTextChanged: searchDebounce.restart()
    onActiveTagFiltersChanged: filterItems()

    // ============ Actions ============
    Process {
        id: copyProcess
        command: ["echo"]
        onExited: code => {
            if (code !== 0) {
                console.error("clipboard re-activate failed, exit code:", code)
            }
            root.closeWithAnimation()
        }
    }

    Process {
        id: deleteProcess
        command: ["echo"]
    }

    Process {
        id: clearProcess
        command: ["bash", "-c", "cliphist wipe && rm -rf '" + cacheDir + "'"]
    }

    Process {
        id: getFullText
        property string targetId: ""
        command: ["bash", "-c", "echo"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root.previewFullText = data
            }
        }
    }

    function showPreview(item) {
        previewItem = item
        previewVisible = true
        if (item.isFile) {
            getFullText.targetId = item.id
            getFullText.command = ["bash", "-c", "cliphist decode '" + item.id + "'"]
            getFullText.running = true
        } else if (!item.isImage) {
            getFullText.targetId = item.id
            getFullText.command = ["bash", "-c", "cliphist decode '" + item.id + "'"]
            getFullText.running = true
        }
    }

    function hidePreview() {
        previewVisible = false
        previewItem = null
        previewFullText = ""
    }

    // ============ Re-activation (二次激活) ============
    // 1. Hash BEFORE wl-copy to prevent sync daemon race condition
    // 2. Dual clipboard: wl-copy (Wayland) + xclip (X11), keep original MIME type
    function selectItem(item) {
        var x11Helper =
            'xclip_try(){ ' +
                'if [ -n "${DISPLAY:-}" ]; then xclip "$@" 2>/dev/null && return 0; fi; ' +
                'for d in :0 :1 :2 :3; do DISPLAY="$d" xclip "$@" 2>/dev/null && return 0; done; ' +
                'return 1; }; ' +
            'prefer_uri_for_image(){ local p="$1"; local mode="${QS_IMAGE_FILE_MODE:-auto}"; ' +
                'case "$mode" in ' +
                    'uri) return 0 ;; ' +
                    'image) return 1 ;; ' +
                'esac; ' +
                'case "$p" in ' +
                    '*/.config/QQ/*/nt_data/Pic/*/Thumb/*|*/.config/QQ/*/nt_data/Pic/*/Thumb/*.*) return 0 ;; ' +
                'esac; ' +
                'return 1; }; ' +
            'x11_set_file(){ local f="$1"; shift; xclip_try "$@" -i < "$f" || return 1; sleep 0.06; xclip_try "$@" -i < "$f" || true; }; '
        if (item.isFile) {
            copyProcess.command = ["bash", "-c",
                x11Helper +
                'HF_DIR="${XDG_RUNTIME_DIR:-/tmp}/clipboard-sync"; mkdir -p "$HF_DIR" 2>/dev/null || true; HF="$HF_DIR/last_hash"; ' +
                'tmp=$(mktemp); tmp_uris=$(mktemp); ' +
                'cleanup(){ rm -f "$tmp" "$tmp_uris"; }; ' +
                'if ! cliphist decode \'' + item.id + '\' > "$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then cleanup; exit 1; fi; ' +
                'while IFS= read -r line || [ -n "$line" ]; do ' +
                    'line="${line%$\'\\r\'}"; ' +
                    '[ -z "$line" ] && continue; ' +
                    'if [[ "$line" == copy\\ * ]]; then line="${line#copy }"; fi; ' +
                    'if [[ "$line" == cut\\ * ]]; then line="${line#cut }"; fi; ' +
                    '[ "$line" = "copy" ] && continue; ' +
                    '[ "$line" = "cut" ] && continue; ' +
                    'for token in $line; do ' +
                        '[ -z "$token" ] && continue; ' +
                        'if [[ "$token" == /* ]]; then printf "file://%s\\n" "$token"; else printf "%s\\n" "$token"; fi; ' +
                    'done; ' +
                'done < "$tmp" > "$tmp_uris"; ' +
                'if [ ! -s "$tmp_uris" ]; then cleanup; exit 1; fi; ' +
                'first=$(sed -n "1p" "$tmp_uris"); second=$(sed -n "2p" "$tmp_uris"); ' +
                'path=""; ' +
                'if [ -n "$first" ] && [ -z "$second" ]; then ' +
                    'case "$first" in file://localhost/*) path="/${first#file://localhost/}" ;; file:///*) path="${first#file://}" ;; /*) path="$first" ;; esac; ' +
                'fi; ' +
                'if [ -n "$path" ] && [ -f "$path" ]; then ' +
                    'mime=$(file -Lb --mime-type -- "$path" 2>/dev/null || true); ' +
                    'if [[ "$mime" == image/* ]] && [ "$mime" != "image/gif" ] && ! prefer_uri_for_image "$path"; then ' +
                        'sha256sum "$path" 2>/dev/null | cut -d" " -f1 > "$HF" 2>/dev/null; ' +
                        'wl-copy --type "$mime" < "$path"; ' +
                        'x11_set_file "$path" -selection clipboard -t "$mime"; ' +
                        'cleanup; exit 0; ' +
                    'fi; ' +
                'fi; ' +
                'sha256sum "$tmp_uris" 2>/dev/null | cut -d" " -f1 > "$HF" 2>/dev/null; ' +
                'wl-copy --type text/uri-list < "$tmp_uris"; ' +
                'x11_set_file "$tmp_uris" -selection clipboard -t text/uri-list; ' +
                'cleanup; exit 0'
            ]
        } else if (item.isImage) {
            var cacheImagePath = imagePathById(item.id)
            copyProcess.command = ["bash", "-c",
                x11Helper +
                'HF_DIR="${XDG_RUNTIME_DIR:-/tmp}/clipboard-sync"; mkdir -p "$HF_DIR" 2>/dev/null || true; HF="$HF_DIR/last_hash"; ' +
                'tmp=$(mktemp); status=1; ' +
                'copy_image(){ local src="$1"; local mime; mime=$(file -b --mime-type "$src" 2>/dev/null || true); ' +
                    'if [[ "$mime" != image/* ]]; then return 1; fi; ' +
                    'if [ "$mime" = "image/png" ]; then ' +
                        'sha256sum "$src" 2>/dev/null | cut -d" " -f1 > "$HF" 2>/dev/null; ' +
                        'wl-copy --type image/png < "$src"; x11_set_file "$src" -selection clipboard -t image/png; return 0; fi; ' +
                    'if [ "$mime" = "image/gif" ]; then ' +
                        'sha256sum "$src" 2>/dev/null | cut -d" " -f1 > "$HF" 2>/dev/null; ' +
                        'wl-copy --type image/gif < "$src"; ' +
                        'x11_set_file "$src" -selection clipboard -t image/gif; return 0; fi; ' +
                    'sha256sum "$src" 2>/dev/null | cut -d" " -f1 > "$HF" 2>/dev/null; ' +
                    'wl-copy --type "$mime" < "$src"; x11_set_file "$src" -selection clipboard -t "$mime"; return 0; }; ' +
                'if cliphist decode "' + item.id + '" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then copy_image "$tmp"; status=$?; fi; ' +
                'rm -f "$tmp"; ' +
                'if [ $status -ne 0 ]; then ' +
                    'for c in "' + cacheImagePath + '" "' + cacheDir + '/' + item.id + '.png" "' + cacheDir + '/' + item.id + '.gif" "' + cacheDir + '/' + item.id + '.jpeg" "' + cacheDir + '/' + item.id + '.jpg" "' + cacheDir + '/' + item.id + '.webp"; do ' +
                        'if [ -s "$c" ]; then copy_image "$c"; status=$?; [ $status -eq 0 ] && break; fi; ' +
                    'done; ' +
                'fi; ' +
                'exit $status'
            ]
        } else {
            var htmlLocalPath = ""
            if (item.textType === "html" && item.htmlImageSrcs && item.htmlImageSrcs.length > 0) {
                htmlLocalPath = normalizeLocalPath(item.htmlImageSrcs[0])
                if (!htmlLocalPath || htmlLocalPath.charAt(0) !== "/") htmlLocalPath = ""
            }

            if (htmlLocalPath) {
                copyProcess.command = ["bash", "-c",
                    x11Helper +
                    'HF_DIR="${XDG_RUNTIME_DIR:-/tmp}/clipboard-sync"; mkdir -p "$HF_DIR" 2>/dev/null || true; HF="$HF_DIR/last_hash"; ' +
                    'tmp_uris=$(mktemp); cleanup(){ rm -f "$tmp_uris"; }; ' +
                    'path=' + shellQuote(htmlLocalPath) + '; ' +
                    'mime=$(file -Lb --mime-type -- "$path" 2>/dev/null || true); ' +
                    'if [[ "$mime" == image/* ]] && [ "$mime" != "image/gif" ] && ! prefer_uri_for_image "$path"; then ' +
                        'sha256sum "$path" 2>/dev/null | cut -d" " -f1 > "$HF" 2>/dev/null; ' +
                        'wl-copy --type "$mime" < "$path"; ' +
                        'x11_set_file "$path" -selection clipboard -t "$mime"; ' +
                        'cleanup; exit 0; ' +
                    'fi; ' +
                    'printf "file://%s\\n" "$path" > "$tmp_uris"; ' +
                    'sha256sum "$tmp_uris" 2>/dev/null | cut -d" " -f1 > "$HF" 2>/dev/null; ' +
                    'wl-copy --type text/uri-list < "$tmp_uris"; ' +
                    'x11_set_file "$tmp_uris" -selection clipboard -t text/uri-list; ' +
                    'cleanup; exit 0'
                ]
            } else if (item.textType === "html" && item.htmlPreferPlain && item.htmlPlainText && item.htmlPlainText.length > 0) {
                copyProcess.command = ["bash", "-c",
                    x11Helper +
                    'HF_DIR="${XDG_RUNTIME_DIR:-/tmp}/clipboard-sync"; mkdir -p "$HF_DIR" 2>/dev/null || true; HF="$HF_DIR/last_hash"; ' +
                    'tmp=$(mktemp); ' +
                    'printf "%s" ' + shellQuote(item.htmlPlainText) + ' > "$tmp"; ' +
                    'sha256sum "$tmp" 2>/dev/null | cut -d" " -f1 > "$HF" 2>/dev/null; ' +
                    'wl-copy --type text/plain;charset=utf-8 < "$tmp"; ' +
                    'x11_set_file "$tmp" -selection clipboard -t UTF8_STRING || x11_set_file "$tmp" -selection clipboard -t text/plain; ' +
                    'rm -f "$tmp"'
                ]
            } else {
            var mimeFlag = item.textType === "html" ? '--type text/html ' : ''
            var xclipTypeFlag = '-t UTF8_STRING '
            copyProcess.command = ["bash", "-c",
                x11Helper +
                'HF_DIR="${XDG_RUNTIME_DIR:-/tmp}/clipboard-sync"; mkdir -p "$HF_DIR" 2>/dev/null || true; HF="$HF_DIR/last_hash"; ' +
                'tmp=$(mktemp); ' +
                'cliphist decode \'' + item.id + '\' > "$tmp" 2>/dev/null; ' +
                'sha256sum "$tmp" 2>/dev/null | cut -d" " -f1 > "$HF" 2>/dev/null; ' +
                'wl-copy ' + mimeFlag + '< "$tmp"; ' +
                'x11_set_file "$tmp" -selection clipboard ' + xclipTypeFlag + ' || x11_set_file "$tmp" -selection clipboard -t text/plain; ' +
                'rm -f "$tmp"'
            ]
            }
        }
        copyProcess.running = true
    }

    function deleteItem(item) {
        deleteProcess.command = ["bash", "-c", "cliphist list | grep -m1 '^" + item.id + "\t' | cliphist delete"]
        deleteProcess.running = true
        clipboardItems = clipboardItems.filter(i => i.id !== item.id)
        rebuildItemIndexMap()
        rebuildTagCounts()
        filterItems()
    }

    function clearAll() {
        clearProcess.running = true
        clipboardItems = []
        filteredItems = []
        itemIndexById = ({})
        tagCounts = ({})
        pendingDecodeIds = []
        pendingDecodeCursor = 0
        decodeChunkTimer.running = false
        mimeProbeStartTimer.running = false
        imageDecodeStartTimer.running = false
        videoThumbStartTimer.running = false
    }

    function selectCurrent() {
        if (filteredItems.length > 0 && selectedIndex < filteredItems.length) {
            selectItem(filteredItems[selectedIndex])
        }
    }

    Component.onCompleted: {
        loading = true
        loadClipboard.running = true
        enterAnimation.start()
    }

    // ============ Animations ============
    ParallelAnimation {
        id: enterAnimation
        NumberAnimation { target: root; property: "panelOpacity"; from: 0; to: 1; duration: 20 }
        NumberAnimation { target: root; property: "panelScale"; from: 0.98; to: 1.0; duration: 20 }
        NumberAnimation { target: root; property: "panelY"; from: 4; to: 0; duration: 20 }
    }

    ParallelAnimation {
        id: exitAnimation
        NumberAnimation { target: root; property: "panelOpacity"; to: 0; duration: 20 }
        NumberAnimation { target: root; property: "panelScale"; to: 0.98; duration: 20 }
        NumberAnimation { target: root; property: "panelY"; to: -4; duration: 20 }
        onFinished: Qt.quit()
    }

    function closeWithAnimation() {
        exitAnimation.start()
    }

    // ============ UI ============
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property ShellScreen modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell-clipboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Shortcut { sequence: "Escape"; onActivated: root.previewVisible ? root.hidePreview() : root.closeWithAnimation() }
            Shortcut { sequence: "Return"; onActivated: root.selectCurrent() }
            Shortcut { sequence: "Enter"; onActivated: root.selectCurrent() }
            Shortcut {
                sequence: "Up"
                onActivated: { if (root.selectedIndex > 0) root.selectedIndex-- }
            }
            Shortcut {
                sequence: "Down"
                onActivated: {
                    if (root.selectedIndex < root.filteredItems.length - 1) root.selectedIndex++
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithAnimation()
            }

            Rectangle {
                id: mainContainer
                anchors.top: root.anchorTop ? parent.top : undefined
                anchors.bottom: root.anchorBottom ? parent.bottom : undefined
                anchors.left: root.anchorLeft ? parent.left : undefined
                anchors.right: root.anchorRight ? parent.right : undefined
                anchors.horizontalCenter: root.anchorHCenter ? parent.horizontalCenter : undefined
                anchors.verticalCenter: root.anchorVCenter ? parent.verticalCenter : undefined
                anchors.topMargin: root.anchorTop ? root.marginT : 0
                anchors.bottomMargin: root.anchorBottom ? root.marginB : 0
                anchors.leftMargin: root.anchorLeft ? root.marginL : 0
                anchors.rightMargin: root.anchorRight ? root.marginR : 0
                width: 650
                height: 550
                color: Theme.background
                radius: Theme.radiusXL
                border.color: Theme.outline
                border.width: 1

                opacity: root.panelOpacity
                scale: root.panelScale
                transform: Translate { y: root.panelY }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { mouse.accepted = true }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingL

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            text: "\uf0ea"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 20
                            color: Theme.primary
                        }

                        Text {
                            text: "剪贴板"
                            font.pixelSize: Theme.fontSizeL
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.filteredItems.length + " 条记录"
                            font.pixelSize: Theme.fontSizeXS
                            color: Theme.textMuted
                        }

                        Rectangle {
                            width: 28; height: 28
                            radius: Theme.radiusM
                            color: clearHover.hovered ? Theme.alpha(Theme.error, 0.1) : "transparent"
                            visible: root.clipboardItems.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "\uf1f8"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 14
                                color: clearHover.hovered ? Theme.error : Theme.textMuted
                            }

                            HoverHandler { id: clearHover }
                            TapHandler { onTapped: root.clearAll() }
                        }

                        Rectangle {
                            width: 28; height: 28
                            radius: Theme.radiusM
                            color: closeHover.hovered ? Theme.surfaceVariant : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 16
                                color: Theme.textSecondary
                            }

                            HoverHandler { id: closeHover }
                            TapHandler { onTapped: root.closeWithAnimation() }
                        }
                    }

                    // Search
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Theme.radiusL
                        color: Theme.surface
                        border.color: searchInput.activeFocus ? Theme.primary : Theme.outline
                        border.width: searchInput.activeFocus ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            Text {
                                text: "\uf002"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 14
                                color: Theme.textMuted
                                Layout.alignment: Qt.AlignVCenter
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                font.pixelSize: Theme.fontSizeM
                                color: Theme.textPrimary
                                clip: true
                                focus: true
                                verticalAlignment: TextInput.AlignVCenter
                                onTextChanged: root.searchText = text

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "搜索内容或 #标签（如 #image #代码）..."
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textMuted
                                    visible: !searchInput.text
                                }
                            }

                            Rectangle {
                                width: 28
                                height: 28
                                Layout.alignment: Qt.AlignVCenter
                                radius: Theme.radiusM
                                color: root.showTagFilters
                                    ? Theme.alpha(Theme.primary, 0.14)
                                    : (tagToggleHover.hovered ? Theme.surfaceVariant : "transparent")
                                border.color: root.showTagFilters ? Theme.primary : "transparent"
                                border.width: root.showTagFilters ? 1 : 0

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf0b0"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 13
                                    color: root.showTagFilters ? Theme.primary : Theme.textMuted
                                }

                                HoverHandler { id: tagToggleHover }
                                TapHandler { onTapped: root.showTagFilters = !root.showTagFilters }
                            }
                        }
                    }

                    // Tag filters
                    Flickable {
                        visible: root.showTagFilters || root.activeTagFilters.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 30 : 0
                        contentWidth: tagFilterRow.implicitWidth
                        contentHeight: height
                        clip: true
                        interactive: contentWidth > width
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: tagFilterRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            Repeater {
                                model: root.tagFilterOptions

                                Rectangle {
                                    required property var modelData
                                    property string tagId: modelData.id
                                    property bool active: root.activeTagFilters.indexOf(tagId) !== -1
                                    property int count: root.tagCount(tagId)
                                    visible: count > 0 || active
                                    height: 28
                                    width: tagChipContent.implicitWidth + Theme.spacingM * 2
                                    radius: 14
                                    color: active ? Theme.alpha(Theme.primary, 0.14) : Theme.surface
                                    border.color: active ? Theme.primary : Theme.outline
                                    border.width: active ? 2 : 1

                                    Row {
                                        id: tagChipContent
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: modelData.icon || "\uf02b"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 10
                                            color: active ? Theme.primary : Theme.textSecondary
                                        }

                                        Text {
                                            text: modelData.label + " " + count
                                            font.pixelSize: Theme.fontSizeXS
                                            color: active ? Theme.primary : Theme.textSecondary
                                        }
                                    }

                                    TapHandler { onTapped: root.toggleTagFilter(tagId) }
                                }
                            }

                            Rectangle {
                                visible: root.activeTagFilters.length > 0
                                height: 28
                                width: clearTagLabel.implicitWidth + Theme.spacingM * 2
                                radius: 14
                                color: Theme.alpha(Theme.error, 0.1)
                                border.color: Theme.error
                                border.width: 1

                                Text {
                                    id: clearTagLabel
                                    anchors.centerIn: parent
                                    text: "清除标签"
                                    font.pixelSize: Theme.fontSizeXS
                                    color: Theme.error
                                }

                                TapHandler { onTapped: root.clearTagFilters() }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                    // List
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: listFlickable
                            anchors.fill: parent
                            anchors.rightMargin: listScrollbar.visible ? 10 : 0
                            contentHeight: itemsCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: itemsCol
                                width: parent.width
                                spacing: Theme.spacingS

                                // Empty state
                                ColumnLayout {
                                    visible: root.filteredItems.length === 0 && !root.loading
                                    Layout.fillWidth: true
                                    Layout.topMargin: Theme.spacingXL * 2
                                    spacing: Theme.spacingM

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "\uf0ea"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 48
                                        color: Theme.outline
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (root.searchText || root.activeTagFilters.length > 0) ? "没有匹配" : "剪贴板为空"
                                        font.pixelSize: Theme.fontSizeM
                                        color: Theme.textMuted
                                    }
                                }

                                // Loading
                                Text {
                                    visible: root.loading
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: Theme.spacingXL * 2
                                    text: "加载中..."
                                    font.pixelSize: Theme.fontSizeM
                                    color: Theme.textMuted
                                }

                                // Items
                                Repeater {
                                    model: root.filteredItems

                                    Rectangle {
                                        id: clipItem
                                        required property var modelData
                                        required property int index

                                        property var badge: root.typeBadgeInfo(modelData)
                                        property bool hasVisualPreview: !!modelData.hasVisualPreview
                                        property bool inViewport: (y + height) >= (listFlickable.contentY - 120)
                                            && y <= (listFlickable.contentY + listFlickable.height + 120)

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: hasVisualPreview ? 80 : 56
                                        radius: Theme.radiusM
                                        color: index === root.selectedIndex
                                            ? Theme.alpha(Theme.primary, 0.1)
                                            : (itemHover.hovered ? Theme.surfaceVariant : Theme.surface)
                                        border.color: index === root.selectedIndex ? Theme.primary : Theme.outline
                                        border.width: index === root.selectedIndex ? 2 : 1

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        HoverHandler { id: itemHover }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function(mouse) {
                                                if (mouse.button === Qt.RightButton) {
                                                    root.showPreview(clipItem.modelData)
                                                } else {
                                                    root.selectItem(clipItem.modelData)
                                                }
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingM

                                            // Column 1: Type icon (always visible)
                                            Rectangle {
                                                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                                Layout.alignment: Qt.AlignVCenter
                                                radius: Theme.radiusS
                                                color: Theme.alpha(clipItem.badge.color, 0.1)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: clipItem.badge.icon
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 14
                                                    color: clipItem.badge.color
                                                }
                                            }

                                            // Column 2: Type badge label (always visible)
                                            Rectangle {
                                                Layout.alignment: Qt.AlignVCenter
                                                width: 38
                                                height: typeBadgeLabel.implicitHeight + 6
                                                radius: 4
                                                color: Theme.alpha(clipItem.badge.color, 0.15)

                                                Text {
                                                    id: typeBadgeLabel
                                                    anchors.centerIn: parent
                                                    text: clipItem.badge.label
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: clipItem.badge.color
                                                }
                                            }

                                            // Column 3: Visual preview (conditional)
                                            Rectangle {
                                                visible: clipItem.hasVisualPreview
                                                Layout.preferredWidth: 64; Layout.preferredHeight: 64
                                                Layout.alignment: Qt.AlignVCenter
                                                radius: Theme.radiusS
                                                color: Theme.surfaceVariant
                                                clip: true

                                                // Binary image (from cliphist decode)
                                                AnimatedImage {
                                                    id: previewBinaryImg
                                                    anchors.fill: parent; anchors.margins: 2
                                                    visible: clipItem.inViewport && clipItem.modelData.isImage
                                                    source: (clipItem.inViewport && clipItem.modelData.isImage && root.imagePaths[clipItem.modelData.id])
                                                        ? "file://" + root.imagePaths[clipItem.modelData.id] : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    playing: clipItem.inViewport; asynchronous: true
                                                }

                                                // File image (static)
                                                Image {
                                                    id: previewFileImg
                                                    anchors.fill: parent; anchors.margins: 2
                                                    visible: clipItem.inViewport && clipItem.modelData.isFile && clipItem.modelData.fileType === "image"
                                                    source: (clipItem.inViewport && clipItem.modelData.isFile && clipItem.modelData.fileType === "image" && clipItem.modelData.filePaths.length > 0)
                                                        ? "file://" + clipItem.modelData.filePaths[0] : ""
                                                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                                                }

                                                // File GIF (animated)
                                                AnimatedImage {
                                                    id: previewFileGif
                                                    anchors.fill: parent; anchors.margins: 2
                                                    visible: clipItem.inViewport && clipItem.modelData.isFile && clipItem.modelData.fileType === "gif"
                                                    source: (clipItem.inViewport && clipItem.modelData.isFile && clipItem.modelData.fileType === "gif" && clipItem.modelData.filePaths.length > 0)
                                                        ? "file://" + clipItem.modelData.filePaths[0] : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    playing: clipItem.inViewport; asynchronous: true
                                                }

                                                // File video thumbnail
                                                Image {
                                                    id: previewVideoThumb
                                                    anchors.fill: parent; anchors.margins: 2
                                                    visible: clipItem.inViewport && clipItem.modelData.isFile && clipItem.modelData.fileType === "video"
                                                    source: (clipItem.inViewport && clipItem.modelData.isFile && clipItem.modelData.fileType === "video" && clipItem.modelData.filePaths.length > 0)
                                                        ? (root.videoThumbPaths[clipItem.modelData.filePaths[0]]
                                                            ? "file://" + root.videoThumbPaths[clipItem.modelData.filePaths[0]] : "") : ""
                                                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                                                }

                                                // HTML embedded image
                                                AnimatedImage {
                                                    id: previewHtmlImg
                                                    anchors.fill: parent; anchors.margins: 2
                                                    visible: clipItem.inViewport && clipItem.modelData.textType === "html" && clipItem.modelData.htmlImageSrcs && clipItem.modelData.htmlImageSrcs.length > 0 && root.isLocalImagePath(clipItem.modelData.htmlImageSrcs[0])
                                                    source: (clipItem.inViewport && clipItem.modelData.textType === "html" && clipItem.modelData.htmlImageSrcs && clipItem.modelData.htmlImageSrcs.length > 0 && root.isLocalImagePath(clipItem.modelData.htmlImageSrcs[0]))
                                                        ? root.localFileUrl(clipItem.modelData.htmlImageSrcs[0]) : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    playing: clipItem.inViewport; asynchronous: true
                                                }

                                                // Fallback icon when no image loaded
                                                Text {
                                                    visible: clipItem.inViewport && clipItem.hasVisualPreview && previewBinaryImg.status !== Image.Ready && previewFileImg.status !== Image.Ready && previewFileGif.status !== Image.Ready && previewVideoThumb.status !== Image.Ready && previewHtmlImg.status !== Image.Ready
                                                    anchors.centerIn: parent
                                                    text: "\uf03e"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 20
                                                    color: Theme.textMuted
                                                }

                                                // Video play overlay
                                                Rectangle {
                                                    visible: clipItem.modelData.isFile && clipItem.modelData.fileType === "video" && previewVideoThumb.status === Image.Ready
                                                    anchors.centerIn: parent
                                                    width: 20; height: 20; radius: 10
                                                    color: Theme.alpha(Qt.black, 0.5)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf04b"
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 8; color: "white"
                                                    }
                                                }

                                                // GIF badge overlay
                                                Rectangle {
                                                    visible: (clipItem.modelData.isFile && clipItem.modelData.fileType === "gif") || (clipItem.modelData.isImage && clipItem.modelData.preview.toLowerCase().indexOf("gif") >= 0)
                                                    anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 3
                                                    width: gifOvLabel.implicitWidth + 6; height: gifOvLabel.implicitHeight + 3
                                                    radius: 3; color: Theme.alpha(Qt.black, 0.6)

                                                    Text {
                                                        id: gifOvLabel; anchors.centerIn: parent
                                                        text: "GIF"; font.pixelSize: 8; font.bold: true; color: "white"
                                                    }
                                                }

                                                // HTML badge overlay
                                                Rectangle {
                                                    visible: clipItem.modelData.textType === "html" && previewHtmlImg.visible
                                                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 3
                                                    width: htmlOvLabel.implicitWidth + 6; height: htmlOvLabel.implicitHeight + 3
                                                    radius: 3; color: Theme.alpha(Qt.black, 0.6)

                                                    Text {
                                                        id: htmlOvLabel; anchors.centerIn: parent
                                                        text: "HTML"; font.pixelSize: 7; font.bold: true; color: "white"
                                                    }
                                                }
                                            }

                                            // Color swatch (inline, only for color type)
                                            Rectangle {
                                                visible: !clipItem.modelData.isImage && !clipItem.modelData.isFile && clipItem.modelData.textType === "color"
                                                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                                Layout.alignment: Qt.AlignVCenter
                                                radius: Theme.radiusS
                                                color: clipItem.modelData.colorValue || "transparent"
                                                border.color: Theme.outline; border.width: 1
                                            }

                                            // Column 4: Content info
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.fillHeight: true
                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: clipItem.modelData.preview
                                                    font.pixelSize: Theme.fontSizeS
                                                    color: clipItem.modelData.isImage ? Theme.textSecondary : Theme.textPrimary
                                                    elide: clipItem.modelData.isFile ? Text.ElideMiddle : Text.ElideRight
                                                    maximumLineCount: 1
                                                }

                                                // File path info
                                                Text {
                                                    visible: clipItem.modelData.isFile && clipItem.modelData.filePaths.length > 0
                                                    Layout.fillWidth: true
                                                    text: {
                                                        if (!clipItem.modelData.isFile || clipItem.modelData.filePaths.length === 0) return ""
                                                        var p = clipItem.modelData.filePaths[0]
                                                        var dir = p.substring(0, p.lastIndexOf("/"))
                                                        var suffix = clipItem.modelData.filePaths.length > 1
                                                            ? "  (+" + (clipItem.modelData.filePaths.length - 1) + " 文件)" : ""
                                                        return dir + suffix
                                                    }
                                                    font.pixelSize: Theme.fontSizeXS
                                                    color: Theme.textMuted
                                                    elide: Text.ElideMiddle
                                                    maximumLineCount: 1
                                                }

                                            }

                                            // Delete button
                                            Rectangle {
                                                width: 24; height: 24
                                                radius: 12
                                                Layout.alignment: Qt.AlignVCenter
                                                color: delHover.hovered ? Theme.alpha(Theme.error, 0.2) : "transparent"
                                                visible: itemHover.hovered || delHover.hovered

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf00d"
                                                    font.family: "Symbols Nerd Font Mono"
                                                    font.pixelSize: 10
                                                    color: delHover.hovered ? Theme.error : Theme.textMuted
                                                }

                                                HoverHandler { id: delHover }
                                                TapHandler { onTapped: root.deleteItem(clipItem.modelData) }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Scrollbar
                        Rectangle {
                            id: listScrollbar
                            visible: listFlickable.contentHeight > listFlickable.height
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 6
                            color: "transparent"

                            Rectangle {
                                id: scrollHandle
                                anchors.right: parent.right
                                width: 6
                                height: Math.max(30, parent.height * listFlickable.height / listFlickable.contentHeight)
                                radius: 3
                                color: scrollHandleArea.containsMouse || scrollHandleArea.pressed
                                    ? Theme.textMuted : Theme.alpha(Theme.textMuted, 0.4)
                                y: listFlickable.contentHeight > listFlickable.height
                                    ? listFlickable.contentY / (listFlickable.contentHeight - listFlickable.height) * (parent.height - height)
                                    : 0

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                MouseArea {
                                    id: scrollHandleArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    drag.target: parent
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: listScrollbar.height - scrollHandle.height

                                    onPositionChanged: {
                                        if (drag.active && listFlickable.contentHeight > listFlickable.height) {
                                            var ratio = scrollHandle.y / (listScrollbar.height - scrollHandle.height)
                                            listFlickable.contentY = ratio * (listFlickable.contentHeight - listFlickable.height)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Enter 粘贴 | 右键 预览 | 方向键 导航 | #tag 过滤 | Esc 关闭"
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.textMuted
                    }
                }
            }

            // ============ Preview Overlay ============
            Rectangle {
                visible: root.previewVisible
                anchors.fill: parent
                color: Theme.alpha(Qt.black, 0.5)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.hidePreview()
                }

                property bool isVisualPreview: root.previewItem && (root.previewItem.isImage
                    || (root.previewItem.isFile && root.previewItem.filePaths.length <= 1 && root.previewItem.fileType !== "other")
                    || (root.previewItem.textType === "html" && root.previewItem.htmlImageSrcs && root.previewItem.htmlImageSrcs.length > 0))

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.isVisualPreview ? Math.min(parent.width - 60, 800) : Math.min(parent.width - 60, 700)
                    height: parent.isVisualPreview ? Math.min(parent.height - 60, 650) : Math.min(parent.height - 60, 550)
                    color: Theme.background
                    radius: Theme.radiusXL
                    border.color: Theme.outline
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: function(mouse) { mouse.accepted = true }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXL
                        spacing: Theme.spacingL

                        // Preview Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM

                            Text {
                                text: {
                                    if (!root.previewItem) return "\uf0f6"
                                    if (root.previewItem.isImage) return "\uf03e"
                                    if (root.previewItem.isFile) {
                                        if (root.previewItem.filePaths.length > 1) return "\uf0c5"
                                        if (root.previewItem.fileType === "gif") return "\uf03e"
                                        if (root.previewItem.fileType === "image") return "\uf03e"
                                        if (root.previewItem.fileType === "video") return "\uf03d"
                                        return "\uf15b"
                                    }
                                    return "\uf0f6"
                                }
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 18
                                color: Theme.primary
                            }

                            Text {
                                text: {
                                    if (!root.previewItem) return ""
                                    if (root.previewItem.isImage) return "\u56fe\u7247\u9884\u89c8"
                                    if (root.previewItem.isFile) {
                                        if (root.previewItem.filePaths.length > 1) return "\u6587\u4ef6\u5217\u8868"
                                        if (root.previewItem.fileType === "gif") return "GIF \u9884\u89c8"
                                        if (root.previewItem.fileType === "image") return "\u56fe\u7247\u9884\u89c8"
                                        if (root.previewItem.fileType === "video") return "\u89c6\u9891\u9884\u89c8"
                                        return "\u6587\u4ef6\u4fe1\u606f"
                                    }
                                    return "\u6587\u672c\u9884\u89c8"
                                }
                                font.pixelSize: Theme.fontSizeL
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            // Image metadata in preview header
                            Text {
                                visible: root.previewItem && root.previewItem.isImage && root.previewItem.imageDimensions
                                text: root.previewItem ? (root.previewItem.imageDimensions || "") + (root.previewItem.imageSize ? " | " + root.previewItem.imageSize : "") : ""
                                font.pixelSize: Theme.fontSizeXS
                                color: Theme.textMuted
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 28; height: 28
                                radius: Theme.radiusM
                                color: previewCloseHover.hovered ? Theme.surfaceVariant : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 16
                                    color: Theme.textSecondary
                                }

                                HoverHandler { id: previewCloseHover }
                                TapHandler { onTapped: root.hidePreview() }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.6 }

                        // Preview Content
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Flickable {
                                id: previewFlickable
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: {
                                    if (!root.previewItem) return 0
                                    if (root.previewItem.isImage) return previewImage.height
                                    if (root.previewItem.isFile) {
                                        if (root.previewItem.filePaths.length > 1) return previewFileInfo.implicitHeight
                                        if (root.previewItem.fileType === "gif") return previewGif.height
                                        if (root.previewItem.fileType === "image") return previewFileImage.height
                                        if (root.previewItem.fileType === "video") return previewVideoThumb.height
                                        return previewFileInfo.implicitHeight
                                    }
                                    if (root.previewItem.textType === "html" && root.previewItem.htmlImageSrcs && root.previewItem.htmlImageSrcs.length > 0 && root.isLocalImagePath(root.previewItem.htmlImageSrcs[0]))
                                        return previewHtmlImage.height
                                    return previewTextEdit.contentHeight
                                }
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                // Binary image preview
                                AnimatedImage {
                                    id: previewImage
                                    visible: root.previewItem && root.previewItem.isImage
                                    width: parent.width
                                    source: root.previewItem && root.previewItem.isImage && root.imagePaths[root.previewItem.id]
                                        ? "file://" + root.imagePaths[root.previewItem.id] : ""
                                    fillMode: Image.PreserveAspectFit
                                    playing: true
                                    asynchronous: true
                                }

                                // File image preview
                                Image {
                                    id: previewFileImage
                                    visible: root.previewItem && root.previewItem.isFile && root.previewItem.filePaths.length <= 1 && root.previewItem.fileType === "image"
                                    width: parent.width
                                    source: (root.previewItem && root.previewItem.isFile && root.previewItem.filePaths.length <= 1 && root.previewItem.fileType === "image" && root.previewItem.filePaths.length > 0)
                                        ? "file://" + root.previewItem.filePaths[0] : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                // GIF preview
                                AnimatedImage {
                                    id: previewGif
                                    visible: root.previewItem && root.previewItem.isFile && root.previewItem.filePaths.length <= 1 && root.previewItem.fileType === "gif"
                                    width: parent.width
                                    source: (root.previewItem && root.previewItem.isFile && root.previewItem.filePaths.length <= 1 && root.previewItem.fileType === "gif" && root.previewItem.filePaths.length > 0)
                                        ? "file://" + root.previewItem.filePaths[0] : ""
                                    fillMode: Image.PreserveAspectFit
                                    playing: true
                                    asynchronous: true
                                }

                                // Video thumbnail preview
                                Image {
                                    id: previewVideoThumb
                                    visible: root.previewItem && root.previewItem.isFile && root.previewItem.filePaths.length <= 1 && root.previewItem.fileType === "video"
                                    width: parent.width
                                    source: {
                                        if (!root.previewItem || !root.previewItem.isFile || root.previewItem.filePaths.length > 1 || root.previewItem.fileType !== "video" || root.previewItem.filePaths.length === 0) return ""
                                        var thumb = root.videoThumbPaths[root.previewItem.filePaths[0]]
                                        return thumb ? "file://" + thumb : ""
                                    }
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true

                                    Rectangle {
                                        visible: previewVideoThumb.status === Image.Ready
                                        anchors.centerIn: parent
                                        width: 48; height: 48
                                        radius: 24
                                        color: Theme.alpha(Qt.black, 0.5)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf04b"
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 20
                                            color: "white"
                                        }
                                    }
                                }

                                // HTML embedded image preview
                                AnimatedImage {
                                    id: previewHtmlImage
                                    visible: root.previewItem && root.previewItem.textType === "html" && root.previewItem.htmlImageSrcs && root.previewItem.htmlImageSrcs.length > 0 && root.isLocalImagePath(root.previewItem.htmlImageSrcs[0])
                                    width: parent.width
                                    source: (root.previewItem && root.previewItem.textType === "html" && root.previewItem.htmlImageSrcs && root.previewItem.htmlImageSrcs.length > 0 && root.isLocalImagePath(root.previewItem.htmlImageSrcs[0]))
                                        ? root.localFileUrl(root.previewItem.htmlImageSrcs[0]) : ""
                                    fillMode: Image.PreserveAspectFit
                                    playing: true
                                    asynchronous: true
                                }

                                // File info for non-previewable files
                                ColumnLayout {
                                    id: previewFileInfo
                                    visible: root.previewItem && root.previewItem.isFile && (root.previewItem.filePaths.length > 1 || (root.previewItem.fileType !== "image" && root.previewItem.fileType !== "gif" && root.previewItem.fileType !== "video"))
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.topMargin: Theme.spacingM
                                        text: root.previewFilePaths.length + " 个文件"
                                        font.pixelSize: Theme.fontSizeL
                                        font.bold: true
                                        color: Theme.textPrimary
                                        visible: root.previewFilePaths.length > 1
                                    }

                                    Repeater {
                                        model: root.previewFilePaths

                                        Rectangle {
                                            required property string modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: fileEntryRow.implicitHeight + Theme.spacingM * 2
                                            radius: Theme.radiusM
                                            color: Theme.surface
                                            border.color: Theme.outline
                                            border.width: 1

                                            property string normalizedPath: root.normalizeLocalPath(modelData)
                                            property string fileMime: root.pathMimeCache[normalizedPath] || ""
                                            property string fileExt: modelData.split(".").pop().toLowerCase()
                                            property bool isImageFile: fileMime ? fileMime.startsWith("image/") : (root.imageExts.indexOf(fileExt) !== -1 || root.gifExts.indexOf(fileExt) !== -1)
                                            property bool isGifFile: fileMime ? fileMime === "image/gif" : (fileExt === "gif")

                                            RowLayout {
                                                id: fileEntryRow
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingM
                                                spacing: Theme.spacingM

                                                // File thumbnail or icon
                                                Rectangle {
                                                    Layout.preferredWidth: 48; Layout.preferredHeight: 48
                                                    Layout.alignment: Qt.AlignVCenter
                                                    radius: Theme.radiusS
                                                    color: Theme.surfaceVariant
                                                    clip: true

                                                    AnimatedImage {
                                                        anchors.fill: parent; anchors.margins: 2
                                                        visible: parent.parent.parent.isGifFile
                                                        source: parent.parent.parent.isGifFile ? "file://" + parent.parent.parent.modelData : ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        playing: true
                                                        asynchronous: true
                                                    }

                                                    Image {
                                                        anchors.fill: parent; anchors.margins: 2
                                                        visible: parent.parent.parent.isImageFile && !parent.parent.parent.isGifFile
                                                        source: (parent.parent.parent.isImageFile && !parent.parent.parent.isGifFile) ? "file://" + parent.parent.parent.modelData : ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                    }

                                                    Text {
                                                        visible: !parent.parent.parent.isImageFile
                                                        anchors.centerIn: parent
                                                        text: {
                                                            var ext = parent.parent.parent.fileExt
                                                            var mime = parent.parent.parent.fileMime
                                                            if (mime.startsWith("video/")) return "\uf03d"
                                                            if (mime.startsWith("audio/")) return "\uf001"
                                                            if (root.videoExts.indexOf(ext) !== -1) return "\uf03d"
                                                            if (root.audioExts.indexOf(ext) !== -1) return "\uf001"
                                                            if (root.archiveExts.indexOf(ext) !== -1) return "\uf1c6"
                                                            if (root.docExts.indexOf(ext) !== -1) return "\uf15c"
                                                            return "\uf15b"
                                                        }
                                                        font.family: "Symbols Nerd Font Mono"
                                                        font.pixelSize: 20
                                                        color: Theme.textMuted
                                                    }
                                                }

                                                // File name and path
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.split("/").pop()
                                                        font.pixelSize: Theme.fontSizeM
                                                        font.bold: true
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideMiddle
                                                        maximumLineCount: 1
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.substring(0, modelData.lastIndexOf("/"))
                                                        font.pixelSize: Theme.fontSizeXS
                                                        color: Theme.textMuted
                                                        elide: Text.ElideMiddle
                                                        maximumLineCount: 1
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Text preview (selectable)
                                TextEdit {
                                    id: previewTextEdit
                                    visible: root.previewItem && !root.previewItem.isImage && !root.previewItem.isFile
                                        && !(root.previewItem.textType === "html" && root.previewItem.htmlImageSrcs && root.previewItem.htmlImageSrcs.length > 0 && root.isLocalImagePath(root.previewItem.htmlImageSrcs[0]))
                                    width: parent.width
                                    text: root.previewFullText
                                    font.pixelSize: Theme.fontSizeM
                                    font.family: "monospace"
                                    color: Theme.textPrimary
                                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                    readOnly: true
                                    selectByMouse: true
                                    selectionColor: Theme.primary
                                    selectedTextColor: "white"
                                }
                            }

                            // Preview scrollbar
                            Rectangle {
                                visible: previewFlickable.contentHeight > previewFlickable.height
                                anchors.right: parent.right
                                y: (previewFlickable.contentHeight > previewFlickable.height)
                                    ? previewFlickable.contentY / (previewFlickable.contentHeight - previewFlickable.height) * (parent.height - height)
                                    : 0
                                width: 6
                                height: Math.max(30, parent.height * parent.height / previewFlickable.contentHeight)
                                radius: 3
                                color: pvScrollArea.pressed ? Theme.textMuted : Theme.alpha(Theme.textMuted, 0.5)

                                MouseArea {
                                    id: pvScrollArea
                                    anchors.fill: parent
                                    drag.target: parent
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: previewFlickable.height - parent.height

                                    onPositionChanged: {
                                        if (drag.active) {
                                            var ratio = parent.y / (previewFlickable.height - parent.height)
                                            previewFlickable.contentY = ratio * (previewFlickable.contentHeight - previewFlickable.height)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
