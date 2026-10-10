# Popup.ps1 - LegaSuite / embedded-browser popup reader via IHTMLDocument2.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# The CDK Drive client (and other LegaSuite-based GUIs) renders host-launched
# popups in embedded Internet Explorer controls. Each such control responds to
# a registered Windows message, WM_HTML_GETOBJECT, by handing over its live
# IHTMLDocument2 interface. From that we read labels, inputs, buttons, and
# visible text.
#
# This file is a module-scoped factoring of the proven popups.ps1 script
# shipped in /home/bryan/Projects/cdk-agent-demo. The classification logic for
# labels, inputs, and buttons is unchanged.
#
# The default process the enumerator looks at is wsStart_4 (the CDK Drive GUI
# shell). Pass -ProcessName to target a different host.

$script:IEWinTypeLoaded = $false

function Initialize-GsPopupInterop {
    if ($script:IEWinTypeLoaded) { return }
    if (([System.Management.Automation.PSTypeName]'GreenScript.IEWin').Type) {
        $script:IEWinTypeLoaded = $true
        return
    }

    $cs = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace GreenScript
{
    public static class IEWin
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT { public int Left, Top, Right, Bottom; }

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern uint RegisterWindowMessage(string msg);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam,
            uint fuFlags, uint uTimeout, out IntPtr lpdwResult);

        [DllImport("oleacc.dll")]
        public static extern int ObjectFromLresult(IntPtr lResult, ref Guid riid, IntPtr wParam,
            [MarshalAs(UnmanagedType.IUnknown)] out object pObject);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool EnumChildWindows(IntPtr hwndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern IntPtr GetAncestor(IntPtr hwnd, uint gaFlags);

        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

        public static object GetDocument(IntPtr hwnd)
        {
            uint msg = RegisterWindowMessage("WM_HTML_GETOBJECT");
            IntPtr lres;
            SendMessageTimeout(hwnd, msg, IntPtr.Zero, IntPtr.Zero, 2, 1000, out lres);
            if (lres == IntPtr.Zero) return null;
            Guid iid = new Guid("332C4425-26CB-11D0-B483-00C04FD90119"); // IID_IHTMLDocument2
            object doc;
            ObjectFromLresult(lres, ref iid, IntPtr.Zero, out doc);
            return doc;
        }
    }
}
'@
    Add-Type -TypeDefinition $cs -Language CSharp
    $script:IEWinTypeLoaded = $true
}

function Get-GsPopup {
    <#
    .SYNOPSIS
    Enumerate open LegaSuite / embedded-browser popups and return their
    documents and metadata.

    .DESCRIPTION
    Finds the GUI host process (default wsStart_4, the CDK Drive shell),
    walks its visible top-level windows, locates each Internet Explorer_Server
    child, pulls the live IHTMLDocument2, filters to real popups (URLs
    containing wipopup=true), and returns one record per popup with Title,
    Url, Rect, HWnd, and the live Document (for callers who want to read it
    themselves).

    .PARAMETER ProcessName
    GUI host process name without the .exe extension. Default 'wsStart_4'.

    .PARAMETER UrlFilter
    Regex a popup URL must match to be returned. Default 'wipopup=true'.
    Pass '.' to return every embedded browser control.

    .OUTPUTS
    pscustomobject[] with Title, Url, Rect, HWnd, Document.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [string] $ProcessName = 'wsStart_4',
        [string] $UrlFilter   = 'wipopup=true'
    )

    Initialize-GsPopupInterop

    # The window walk and DOM access below talk to live Win32 / MSHTML COM
    # objects whose member surface varies by window and element type. The
    # proven standalone script ran without strict mode and with
    # SilentlyContinue; mirror that in this function's scope only, so an odd
    # window degrades to "skipped" rather than an exception.
    Set-StrictMode -Off
    $ErrorActionPreference = 'SilentlyContinue'

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $proc) {
            $sw.Stop()
            Write-GsAudit -Session $null -Action 'popup' `
                -Arguments @{ processName = $ProcessName } `
                -Result @{ popups = 0; reason = 'host-process-not-running' } `
                -DurationMs $sw.ElapsedMilliseconds -Ok $true
            return @()
        }
        $procId = $proc.Id

        $tops = New-Object System.Collections.ArrayList
        $cbTop = [GreenScript.IEWin+EnumWindowsProc]{
            param($h, $l)
            $p = [uint32]0
            [void][GreenScript.IEWin]::GetWindowThreadProcessId($h, [ref]$p)
            if ($p -eq $procId -and [GreenScript.IEWin]::IsWindowVisible($h)) {
                [void]$tops.Add($h)
            }
            return $true
        }
        [void][GreenScript.IEWin]::EnumWindows($cbTop, [IntPtr]::Zero)

        $found = New-Object System.Collections.ArrayList
        $cb = [GreenScript.IEWin+EnumWindowsProc]{
            param($h, $l)
            $sb = New-Object System.Text.StringBuilder 256
            [void][GreenScript.IEWin]::GetClassName($h, $sb, 256)
            if ($sb.ToString() -eq 'Internet Explorer_Server') {
                [void]$found.Add($h)
            }
            return $true
        }
        foreach ($t in $tops) {
            [void][GreenScript.IEWin]::EnumChildWindows($t, $cb, [IntPtr]::Zero)
        }

        $results = @()
        foreach ($h in $found) {
            $doc = [GreenScript.IEWin]::GetDocument($h)
            if (-not $doc) { continue }
            $url = [string]$doc.url
            if ($url -notmatch $UrlFilter) { continue }

            $root = [GreenScript.IEWin]::GetAncestor($h, 2)   # GA_ROOT
            $r = New-Object GreenScript.IEWin+RECT
            [void][GreenScript.IEWin]::GetWindowRect($root, [ref]$r)
            $rect = [pscustomobject]@{
                X = $r.Left; Y = $r.Top
                W = $r.Right - $r.Left; H = $r.Bottom - $r.Top
            }

            $results += [pscustomobject]@{
                Title    = [string]$doc.title
                Url      = $url
                Rect     = $rect
                HWnd     = $h
                Document = $doc
            }
        }
        $sw.Stop()
        Write-GsAudit -Session $null -Action 'popup' `
            -Arguments @{ processName = $ProcessName; urlFilter = $UrlFilter } `
            -Result @{ popups = $results.Count } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $true
        return $results
    }
    catch {
        $sw.Stop()
        Write-GsAudit -Session $null -Action 'popup' `
            -Arguments @{ processName = $ProcessName } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $false `
            -ErrorMessage $_.Exception.Message
        throw
    }
}

function Read-GsPopup {
    <#
    .SYNOPSIS
    Read fields, buttons, and visible text out of a popup document.

    .DESCRIPTION
    Takes a popup record from Get-GsPopup and returns a structured parse:
      Title, Url, Rect, Fields (label/id/type/value), Buttons (captions), Text.
    Label resolution tries, in order of trust: <label for=id>, aria-label,
    placeholder, title attribute, and finally the nearest ancestor row's
    innerText with hint/error elements stripped.

    .PARAMETER Popup
    One of the pscustomobject records returned by Get-GsPopup.

    .PARAMETER MaxText
    Maximum characters of visible popup text to return. Default 1500.

    .OUTPUTS
    pscustomobject with Title, Url, Rect, Fields, Buttons, Text.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [pscustomobject] $Popup,
        [ValidateRange(100, 100000)] [int] $MaxText = 1500
    )

    process {
        # See Get-GsPopup: the DOM walk mirrors the proven standalone script's
        # lenient error handling, scoped to this function only. A missing or
        # odd attribute yields an empty label instead of a terminating error.
        Set-StrictMode -Off
        $ErrorActionPreference = 'SilentlyContinue'

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $doc = $Popup.Document
            if (-not $doc) { throw 'Popup document is null.' }

            $labelFor = @{}
            $labels = $doc.getElementsByTagName('label')
            for ($i = 0; $i -lt $labels.length; $i++) {
                $lb = $labels.item($i)
                $for = [string]$lb.htmlFor
                if ($for) {
                    $labelFor[$for] = (([string]$lb.innerText) -replace '\s+', ' ').Trim()
                }
            }

            $fields = @()
            $inputs = $doc.getElementsByTagName('input')
            for ($i = 0; $i -lt $inputs.length; $i++) {
                $e = $inputs.item($i)
                $type = [string]$e.type
                if ($type -in @('hidden', 'submit', 'button', 'image')) { continue }
                $value = [string]$e.value
                $id = [string]$e.id
                $label = ''

                if ($id -and $labelFor.ContainsKey($id)) { $label = $labelFor[$id] }
                if (-not $label) {
                    foreach ($a in @('aria-label', 'placeholder', 'title')) {
                        $v = [string]$e.getAttribute($a)
                        if ($v) { $label = $v; break }
                    }
                }
                if (-not $label) {
                    $p = $e.parentElement; $depth = 0
                    while ($p -and $depth -lt 5) {
                        $t = ([string]$p.innerText) -replace '\s+', ' '
                        $kids = $p.getElementsByTagName('*')
                        for ($k = 0; $k -lt $kids.length; $k++) {
                            $kid = $kids.item($k)
                            $cls = [string]$kid.className
                            if ($cls -match 'help|hint|error|valid|message|msg|tooltip') {
                                $kt = ([string]$kid.innerText) -replace '\s+', ' '
                                if ($kt.Trim()) { $t = $t.Replace($kt.Trim(), '') }
                            }
                        }
                        if ($value.Length -gt 0) { $t = $t.Replace($value, '') }
                        $t = $t.Replace('$', '').Trim()
                        if ($t -match '[A-Za-z]{2,}') { $label = $t; break }
                        $p = $p.parentElement; $depth++
                    }
                }

                if ($label -match '^([^:]*:)') { $label = $Matches[1] }
                if ($label.Length -gt 60) { $label = $label.Substring(0, 60) }
                if ($type -eq 'checkbox' -or $type -eq 'radio') { $value = [string]$e.checked }

                $fields += [pscustomobject]@{
                    Label = $label; Id = $id; Type = $type; Value = $value
                }
            }

            $buttons = @()
            $bs = $doc.getElementsByTagName('button')
            for ($i = 0; $i -lt $bs.length; $i++) {
                $cap = ([string]$bs.item($i).innerText).Trim()
                if ($cap) { $buttons += $cap }
            }

            $text = ([string]$doc.body.innerText) -replace '\s+', ' '
            if ($text.Length -gt $MaxText) { $text = $text.Substring(0, $MaxText) }

            $result = [pscustomobject]@{
                Title   = [string]$doc.title
                Url     = [string]$doc.url
                Rect    = $Popup.Rect
                Fields  = $fields
                Buttons = $buttons
                Text    = $text
            }
            $sw.Stop()
            Write-GsAudit -Session $null -Action 'popup-read' `
                -Arguments @{ title = $result.Title; url = $result.Url } `
                -Result @{ fields = $fields.Count; buttons = $buttons.Count; textLen = $text.Length } `
                -DurationMs $sw.ElapsedMilliseconds -Ok $true
            return $result
        }
        catch {
            $sw.Stop()
            Write-GsAudit -Session $null -Action 'popup-read' `
                -DurationMs $sw.ElapsedMilliseconds -Ok $false `
                -ErrorMessage $_.Exception.Message
            throw
        }
    }
}
