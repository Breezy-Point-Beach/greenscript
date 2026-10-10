# Interop.ps1 - C# shim for BZWhll COM calls that take ByRef parameters.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# BZWhll.WhllObj exposes several late-bound methods whose signatures use VB6
# ByRef conventions:
#   ReadScreen(ByRef buffer As String, ByVal length As Long, ByVal row As Long, ByVal col As Long)
#   GetCursor(ByRef row As Long, ByRef col As Long)
# PowerShell's dynamic COM dispatch does not round-trip ByRef string/long
# values cleanly. The shim below invokes the methods through
# System.Type.InvokeMember with a ParameterModifier that marks the ByRef
# positions, then returns managed values. This is the same technique the
# Rocket samples use from C# / VB.NET.
#
# Everything in this file is defined once per PowerShell session via Add-Type.

if (-not ([System.Management.Automation.PSTypeName]'GreenScript.BlueZoneInterop').Type) {

    $cs = @'
using System;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;

namespace GreenScript
{
    /// <summary>
    /// Thin late-bound wrapper over BZWhll.WhllObj. Keeps ByRef marshaling
    /// out of PowerShell code and returns ordinary managed values.
    /// </summary>
    public sealed class BlueZoneInterop : IDisposable
    {
        private object _host;
        private readonly Type _type;
        private bool _connected;
        private string _sessionTag;

        public string SessionTag { get { return _sessionTag; } }
        public bool IsConnected { get { return _connected; } }

        public BlueZoneInterop()
        {
            _type = Type.GetTypeFromProgID("BZWhll.WhllObj", true);
            if (_type == null)
                throw new InvalidOperationException(
                    "BZWhll.WhllObj is not registered. Install BlueZone (or its CDK bundle) and run under 32-bit PowerShell.");
            _host = Activator.CreateInstance(_type);
        }

        /// <summary>
        /// Attach to a BlueZone session. Pass "" (the default) for the active
        /// session; pass "A", "B", etc. to attach to a specific presentation
        /// space.
        /// </summary>
        public void Connect(string sessionName)
        {
            if (sessionName == null) sessionName = string.Empty;
            _type.InvokeMember("Connect",
                BindingFlags.InvokeMethod, null, _host, new object[] { sessionName });
            _connected = true;
            _sessionTag = string.IsNullOrEmpty(sessionName) ? "<active>" : sessionName;
        }

        /// <summary>
        /// Read a chunk of the terminal buffer. Returns the characters at
        /// (row, col) for the requested length.
        /// </summary>
        public string ReadScreen(int length, int row, int col)
        {
            // ReadScreen(ByRef buffer As String, ByVal length, ByVal row, ByVal col)
            // The buffer argument must be a pre-sized String; we pass a
            // length-char string of spaces, mark position 0 as ByRef, and
            // read the value back out of the args array.
            string buffer = new string(' ', length);
            object[] args = new object[] { buffer, length, row, col };
            ParameterModifier pm = new ParameterModifier(4);
            pm[0] = true;
            ParameterModifier[] mods = new ParameterModifier[] { pm };
            _type.InvokeMember("ReadScreen",
                BindingFlags.InvokeMethod, null, _host, args, mods, null, null);
            string result = args[0] as string;
            if (result == null) return string.Empty;
            // The host often returns a buffer longer than requested; trim.
            if (result.Length > length) result = result.Substring(0, length);
            return result;
        }

        /// <summary>
        /// Return the current cursor position as a 2-int array [row, col].
        /// </summary>
        public int[] GetCursor()
        {
            // GetCursor(ByRef row As Long, ByRef col As Long)
            object[] args = new object[] { 0, 0 };
            ParameterModifier pm = new ParameterModifier(2);
            pm[0] = true;
            pm[1] = true;
            ParameterModifier[] mods = new ParameterModifier[] { pm };
            _type.InvokeMember("GetCursor",
                BindingFlags.InvokeMethod, null, _host, args, mods, null, null);
            int r = Convert.ToInt32(args[0]);
            int c = Convert.ToInt32(args[1]);
            return new int[] { r, c };
        }

        /// <summary>
        /// Send a keystroke sequence. BlueZone's SendKey takes a single
        /// string in which special keys are expressed as angle-bracketed
        /// tokens: <![CDATA[<Enter> <F3> <SF6> <Tab>]]> etc.
        /// </summary>
        public void SendKey(string keys)
        {
            if (keys == null) keys = string.Empty;
            _type.InvokeMember("SendKey",
                BindingFlags.InvokeMethod, null, _host, new object[] { keys });
        }

        /// <summary>
        /// Wait up to <paramref name="timeoutSeconds"/> for <paramref name="text"/>
        /// to appear at (row, col). Returns the BlueZone status code:
        /// 0 = found, 4 = timeout, other = error.
        /// </summary>
        public int WaitForText(string text, int row, int col, int timeoutSeconds)
        {
            if (text == null) text = string.Empty;
            object r = _type.InvokeMember("WaitForText",
                BindingFlags.InvokeMethod, null, _host,
                new object[] { text, row, col, timeoutSeconds });
            return Convert.ToInt32(r);
        }

        public void Disconnect()
        {
            if (!_connected) return;
            try
            {
                _type.InvokeMember("Disconnect",
                    BindingFlags.InvokeMethod, null, _host, null);
            }
            catch { /* best-effort release */ }
            _connected = false;
        }

        public void Dispose()
        {
            Disconnect();
            if (_host != null)
            {
                try { Marshal.ReleaseComObject(_host); } catch { }
                _host = null;
            }
        }
    }
}
'@

    Add-Type -TypeDefinition $cs -Language CSharp
}
