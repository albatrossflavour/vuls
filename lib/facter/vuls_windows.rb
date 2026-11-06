# The two things Vuls needs about a Windows host that PuppetDB does not already
# carry: the update build revision (UBR) and the installed hotfix list.
#
# `kernelrelease` stops at 10.0.20348. Vuls wants 10.0.20348.5622, and the
# revision only exists in the registry: systeminfo.exe does not print it either.
# The hotfix list matters separately, because a standalone out-of-band update
# (KB5012170, the Secure Boot DBX one) is not in the cumulative build chain, so
# the build number alone cannot tell you whether it is applied.
#
# One PowerShell call for both. Roughly two seconds, which is the reason it is
# one call rather than a registry read plus a Get-HotFix.
Facter.add(:vuls_windows) do
  confine kernel: 'windows'

  setcode do
    script = <<~'PS'.gsub(/\s*\n\s*/, ' ')
      $ErrorActionPreference = 'Stop';
      $u = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR;
      Write-Output "UBR=$u";
      Get-HotFix | ForEach-Object { Write-Output "HF=$($_.HotFixID)" }
    PS

    output = Facter::Core::Execution.execute(
      %(powershell.exe -NoProfile -NonInteractive -Command "#{script}"),
      on_fail: nil,
    )
    next nil if output.nil?

    ubr = nil
    hotfixes = []
    output.each_line do |line|
      case line.strip
      when /\AUBR=(\d+)\z/ then ubr = Regexp.last_match(1)
      when /\AHF=(KB\d+)\z/ then hotfixes << Regexp.last_match(1)
      end
    end

    # No UBR means the version string would be wrong rather than incomplete, and
    # Vuls answers a wrong version with a confident zero, so publish nothing.
    next nil if ubr.nil?

    { 'ubr' => ubr, 'hotfixes' => hotfixes.uniq.sort }
  end
end
