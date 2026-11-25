using System;
using System.Runtime.InteropServices;
using System.Text;
using OpenNeko.Windows.Native;

namespace OpenNeko.Windows.Services;

/// <summary>
/// API key storage in Windows Credential Manager (counterpart of App/APIKeyStore.swift
/// and the macOS Keychain). Keys never go to settings.json and are never logged.
/// </summary>
internal sealed class CredentialStore
{
    private static string Target(string presetId) => $"openNeko:apiKey:{presetId}";

    public string? ApiKey(string presetId)
    {
        if (!NativeMethods.CredRead(Target(presetId), NativeMethods.CRED_TYPE_GENERIC, 0, out var pointer)) return null;
        try
        {
            var credential = Marshal.PtrToStructure<NativeMethods.CREDENTIAL>(pointer);
            if (credential.CredentialBlobSize <= 0 || credential.CredentialBlob == IntPtr.Zero) return null;
            var bytes = new byte[credential.CredentialBlobSize];
            Marshal.Copy(credential.CredentialBlob, bytes, 0, bytes.Length);
            var value = Encoding.UTF8.GetString(bytes);
            return value.Length == 0 ? null : value;
        }
        finally
        {
            NativeMethods.CredFree(pointer);
        }
    }

    public bool Save(string presetId, string apiKey)
    {
        var trimmed = apiKey.Trim();
        if (trimmed.Length == 0) return Delete(presetId);
        var bytes = Encoding.UTF8.GetBytes(trimmed);
        var blob = Marshal.AllocHGlobal(bytes.Length);
        try
        {
            Marshal.Copy(bytes, 0, blob, bytes.Length);
            var credential = new NativeMethods.CREDENTIAL
            {
                Type = NativeMethods.CRED_TYPE_GENERIC,
                TargetName = Target(presetId),
                CredentialBlobSize = bytes.Length,
                CredentialBlob = blob,
                Persist = NativeMethods.CRED_PERSIST_LOCAL_MACHINE,
                UserName = "openNeko",
            };
            return NativeMethods.CredWrite(ref credential, 0);
        }
        finally
        {
            // Zero the unmanaged copy before freeing it.
            for (var i = 0; i < bytes.Length; i++) Marshal.WriteByte(blob, i, 0);
            Marshal.FreeHGlobal(blob);
            Array.Clear(bytes);
        }
    }

    public bool Delete(string presetId) => NativeMethods.CredDelete(Target(presetId), NativeMethods.CRED_TYPE_GENERIC, 0);
}
