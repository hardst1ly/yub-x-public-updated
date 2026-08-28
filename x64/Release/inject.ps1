$src = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public static class Injector
{
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr VirtualAllocEx(IntPtr hProc, IntPtr addr, uint size, uint type, uint protect);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteProcessMemory(IntPtr hProc, IntPtr baseAddr, byte[] buffer, uint size, out int written);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr CreateRemoteThread(IntPtr hProc, IntPtr attr, uint stack, IntPtr start, IntPtr param, uint flags, out int tid);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr GetModuleHandleW(string name);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr GetProcAddress(IntPtr mod, string proc);

    public static string Inject(string dllPath, string procName)
    {
        var procs = Process.GetProcessesByName(procName);
        if (procs.Length == 0) return "process '" + procName + "' not found - launch Roblox and join a game first";
        int pid = procs[0].Id;

        const uint PROCESS_CREATE_THREAD = 0x0002;
        const uint PROCESS_QUERY_INFORMATION = 0x0400;
        const uint PROCESS_VM_OPERATION = 0x0008;
        const uint PROCESS_VM_WRITE = 0x0020;
        const uint PROCESS_VM_READ = 0x0010;
        var access = PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ;

        IntPtr hProc = OpenProcess(access, false, pid);
        if (hProc == IntPtr.Zero) return "OpenProcess failed (err " + Marshal.GetLastWin32Error() + ") - run as admin?";

        IntPtr hK32 = GetModuleHandleW("kernel32.dll");
        IntPtr pLoadLib = GetProcAddress(hK32, "LoadLibraryW");
        if (pLoadLib == IntPtr.Zero) return "LoadLibraryW not resolved";

        byte[] dllBytes = Encoding.Unicode.GetBytes(dllPath + "\0");
        IntPtr remoteBuf = VirtualAllocEx(hProc, IntPtr.Zero, (uint)dllBytes.Length, 0x3000 /*MEM_COMMIT|RESERVE*/, 0x04 /*PAGE_READWRITE*/);
        if (remoteBuf == IntPtr.Zero) return "VirtualAllocEx failed (err " + Marshal.GetLastWin32Error() + ")";

        int written;
        if (!WriteProcessMemory(hProc, remoteBuf, dllBytes, (uint)dllBytes.Length, out written))
            return "WriteProcessMemory failed (err " + Marshal.GetLastWin32Error() + ")";

        int tid;
        IntPtr hThread = CreateRemoteThread(hProc, IntPtr.Zero, 0, pLoadLib, remoteBuf, 0, out tid);
        if (hThread == IntPtr.Zero) return "CreateRemoteThread failed (err " + Marshal.GetLastWin32Error() + ")";

        WaitForSingleObject(hThread, 5000);
        return "OK: injected into PID " + pid + " from " + dllPath;
    }
}
"@

Add-Type -TypeDefinition $src -Language CSharp

$dll = "C:\Users\qwes1\Desktop\YuB-X-Public-updated\x64\Release\Module.dll"
$result = [Injector]::Inject($dll, "RobloxPlayerBeta")
Write-Output $result
