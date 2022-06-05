using namespace System;
using namespace System.ComponentModel;
using namespace System.Windows.Controls;
using namespace System.Windows;

using namespace System.Threading;
using namespace Microsoft;

[void] (Add-Type -AssemblyName PresentationFramework);

class ServiceModelData : System.Object
{
    [ValidateNotNullOrEmpty()] [System.String] $script:ServiceStatus;
    [ValidateNotNullOrEmpty()] [System.String] $script:ServiceName;
    [ValidateNotNullOrEmpty()] [System.String] $script:ServiceDisplayName;

    static [ServiceModelData] CreateFromService([System.String] $service_name)
    {
        [ComponentModel.Component] $local:service_item = (Get-Service -Name $service_name);
        return ([ServiceModelData] @{ ServiceDisplayName = ($service_item).DisplayName;
            ServiceStatus = ($service_item).Status; ServiceName = ($service_item).ServiceName; 
        });
    }
}

function local:LoadXamlFormFile([string] ${local:File-Path})
{
    [Xml.XmlDocument] ${local:Xaml-File} = (Get-Content -Path ${local:File-Path});
    [Xml.XmlNodeReader] ${local:Xaml-Reader} = (New-Object System.Xml.XmlNodeReader ${Xaml-File});
    return ([Windows.Markup.XamlReader]::Load(${Xaml-Reader}));
}

#Write-Host("$PSScriptRoot\powershell-view.xaml");

try { ${script:Main-Window} = local:LoadXamlFormFile("$PSScriptRoot\powershell-view.xaml"); }
catch { Write-Host("Can't load Windows.Markup.XamlReader; ($PSItem.Exteption.Message)"); Exit; }

#Write-Host( ${script:Main-Window}.GetType());

[void](New-Variable -Name "service_status_button" -Value ${script:Main-Window}.FindName("ChangeStatusButton") `
    -Scope "Script" -Option "Constant");
[void](New-Variable -Name "service_listview" -Value ${script:Main-Window}.FindName("ServiceList") `
    -Scope "Script" -Option "Constant");
[void](New-Variable -Name "service_requirement" -Value ${script:Main-Window}.FindName("ServiceRequires") `
    -Scope "Script" -Option "Constant");
[void](New-Variable -Name "service_searching" -Value ${script:Main-Window}.FindName("ServiceSearching") `
    -Scope "Script" -Option "Constant");

[void](New-Variable -Name "service_filepath_textbox" -Value ${script:Main-Window}.FindName("FilePathTextBox") `
    -Scope "Script" -Option "Constant");
[void](New-Variable -Name "service_name_property" -Value ${script:Main-Window}.FindName("NameTextBlock") `
    -Scope "Script" -Option "Constant");
[void](New-Variable -Name "service_status_property" -Value ${script:Main-Window}.FindName("StatusTextBlock") `
    -Scope "Script" -Option "Constant");
[void](New-Variable -Name "service_displayname_property" -Value ${script:Main-Window}.FindName("DisplayNameTextBlock") `
    -Scope "Script" -Option "Constant");
[void](New-Variable -Name "service_starttype_property" -Value ${script:Main-Window}.FindName("StartTypeComboBox") `
    -Scope "Script" -Option "Constant");

function script:Set-ListViewItems
{
    [CmdletBinding()] # Advanced function
    param ( [Parameter(ValueFromPipeline)] [ComponentModel.Component[]] $local:ServiceList, 
        [ValidateNotNullOrEmpty()] [ListBox] $ListBoxItem)

    begin { $ListBoxItem.Items.Clear(); }
    process { 
        [ServiceModelData] ${local:Service-Model} = (New-Object -TypeName "ServiceModelData" -Property @{
            ServiceName = ($ServiceList).ServiceName;  ServiceDisplayName = ($ServiceList).DisplayName;
            ServiceStatus = "[ $(if(($ServiceList).Status -eq "Running") {"Работает"} else {"Остановлена"}) ]";
        });
        $ListBoxItem.Items.Add(${local:Service-Model})  
    }
}

function script:ServicePropertyCallBack
{
    [ComponentModel.Component[]] $local:selected_service = (Get-Service -Name ($service_listview.SelectedValue).ServiceName);
    [void] ($script:service_status_button.IsEnabled = $global:true);

    switch($local:selected_service.Status)
    {
        "Running" { $script:service_status_button.Content = [System.String]::new("Остановка службы"); }
        "Stopped" { $script:service_status_button.Content = [System.String]::new("Запуск службы"); }
    }   
    [void] ($script:service_name_property.Text =  ($local:selected_service).ServiceName);
    [void] ($script:service_status_property.Text = 
        if(($local:selected_service).Status -eq "Running" ) {"Работает"} else { "Остановлена" });
    
    [void] ($script:service_displayname_property.Text =  ($local:selected_service).DisplayName);
    [void] ($script:service_starttype_property.Text =  ($local:selected_service).StartType);

    if($local:selected_service.RequiredServices -eq $global:null) { $script:service_requirement.Items.Clear(); return [void]; }
    $local:selected_service.RequiredServices | ForEach-Object -Process {
        [void]((Get-Service -Name $PSItem.ServiceName) | Set-ListViewItems -ListBoxItem $script:service_requirement) };
}

function script:WindowsItemsClear
{
    [void] ($script:service_status_button.IsEnabled = $global:false);
    [void] ($script:service_status_button.Content = "Запуск службы");

    [void] ($script:service_name_property.Text = $global:null);
    [void] ($script:service_status_property.Text =  $global:null);
    
    [void] ($script:service_displayname_property.Text =  $global:null);
    [void] ($script:service_starttype_property.Text =  $global:null);

    $script:service_searching.Text = $global:null;
    $script:service_requirement.Items.Clear();
}

function script:ButtonRefreshCallback()
{  
    [System.ComponentModel.Component[]] ${local:Service-List} = (Get-Service -Name "*");
    [void] (${local:Service-List} | Set-ListViewItems -ListBoxItem $script:service_listview); 
    [void] (script:WindowsItemsClear);
}

function script:ButtonUpdateCallback()
{
    [System.String] $local:service_display_name = $script:service_displayname_property.Text;
    [System.String] $local:service_start_type = $script:service_starttype_property.Text;
    try {
        if(($service_listview.SelectedIndex) -eq -1) { throw ("Служба для редактирования не выбранна"); }
        if(($local:service_display_name).Length -lt 5) { throw ("Неверно заполнены поля"); }

        [void] (Set-Service -Name ([ServiceModelData]$service_listview.SelectedItems[0]).ServiceName `
            -DisplayName $local:service_display_name -StartupType $local:service_start_type);
        [void] (($script:service_listview.SelectedItems[0]).ServiceDisplayName = $local:service_display_name);
    } 
    catch{ [MessageBox]::Show("Невозможно изменить свойства: $($PSItem.Exception.Message)","Ошибка"); }
    
    [void] ($script:service_listview.Items.Refresh());
    [void] (script:ServicePropertyCallBack);
}

function script:ButtonStatusCallback()
{
    [ServiceModelData] $local:selected_service = $service_listview.SelectedItems[0];
    try {
        switch((Get-Service -Name $local:selected_service.ServiceName).Status)
        {
            "Running" { [void] (Get-Service -Name $local:selected_service.ServiceName | Stop-Service -Force); }
            "Stopped" { [void] (Get-Service -Name $local:selected_service.ServiceName | Start-Service); } 
        }
        [void] ($local:selected_service.ServiceStatus = "[ $(
            if((Get-Service -Name $local:selected_service.ServiceName).Status -eq "Running") 
            {"Работает"} else {"Остановлена"}) ]");

    } catch { [MessageBox]::Show("Невозможно изменить состояние","Ошибка"); }
    
    [void] ($script:service_listview.Items.Refresh());
    [void] (script:ServicePropertyCallBack);
}

function script:ServiceSearchingCallback()
{
    for([int]$local:i = 0; $local:i -lt (($script:service_searching.Text).Length); $i++) 
    { 
        if(($script:service_searching.Text)[$i] -notlike "[A-Za-z0-1 ]") { return [void]; } 
    }
    [System.ComponentModel.Component[]]${local:Service-List} = (Get-Service -Name ("*$($script:service_searching.Text)*"));

    if(${local:Service-List} -eq $global:null) { return [void]; }
    [void](${local:Service-List} | Set-ListViewItems -ListBoxItem $script:service_listview); 
}

function script:FilePathServiceCallback()
{
    [Win32.OpenFileDialog] $local:filepath_dialog = [Win32.OpenFileDialog]::new();
    [void] (($local:filepath_dialog).FileName = "Windows Service");
    [void] (($local:filepath_dialog).Filter = "Executable File (.exe)|*.exe");
    [void] (($local:filepath_dialog).DefaultExt = ".exe");

    if(($local:filepath_dialog).ShowDialog() -ne $global:true) { return [void]; }
    [void] (($script:service_filepath_textbox).Text = $local:filepath_dialog.FileName);
}

function script:NewServiceCallback()
{
    [System.String] $local:new_service_name = (${script:Main-Window}.FindName("NewServiceName")).Text;
    [System.String] $local:new_service_diplayname = (${script:Main-Window}.FindName("NewServiceDisplayName")).Text;

    if(($local:new_service_name.Length -le 5) -or ($local:new_service_diplayname.Length -le 5)) { return [void]; }
    try {
        [Collections.ArrayList] $local:cmdler_error = $global:null; 

        [void] (New-Service -Name $local:new_service_name -DisplayName $local:new_service_diplayname `
            -BinaryPathName ($script:service_filepath_textbox).Text -ErrorVariable cmdler_error `
            -ErrorAction SilentlyContinue);

        if($local:cmdler_error -ne $global:null) { throw [System.Exception]::new("Cmdlet Error"); }
        [MessageBox]::Show("Служба была создана","Успешно");
    } catch { [MessageBox]::Show("Невозможно создать службу; $($PSItem.Exception.Message)","Ошибка"); }
    
    [void] (script:WindowsItemsClear);
}

function script:DeleteServiceCallback()
{
    [System.String] $local:selected_service = ($service_listview.SelectedValue).ServiceName;
    if($local:selected_service -eq [System.String]::Empty) { return [void]; }

    try { 
        [void] (Get-Service -Name $local:selected_service | Stop-Service -Force);
        [void] ((Get-WmiObject Win32_Service -Filter ("name='$local:selected_service'")).Delete());
        
        [MessageBox]::Show("Выбранная служба была удалена","Успешно"); 
    } catch { [MessageBox]::Show(" Невозможно удалить службу; $($PSItem.Exception.Message)","Ошибка"); }
    [void] (script:WindowsItemsClear);
}

${script:Main-Window}.FindName("ServiceRefreshButton").Add_Click($function:ButtonRefreshCallback)
${script:Main-Window}.FindName("UpdateServiceButton").Add_Click($function:ButtonUpdateCallback);
$script:service_status_button.Add_Click($function:ButtonStatusCallback);

$script:service_listview.Add_MouseUp($function:ServicePropertyCallBack);
$script:service_searching.Add_TextChanged($function:ServiceSearchingCallback);

${script:Main-Window}.FindName("NewServiceButton").Add_Click($function:NewServiceCallback);
${script:Main-Window}.FindName("DeleteServiceButton").Add_Click($function:DeleteServiceCallback);
${script:Main-Window}.FindName("OpenFileButton").Add_Click($function:FilePathServiceCallback);

${script:Main-Window}.FindName("MenuItemInfoButton").Add_Click({
    [MessageBox]::Show("Курсовая работа на тему 'Управление службами Windows' [бИСТ-214]","Информация");});

[void](Invoke-Command -ScriptBlock {script:ButtonRefreshCallback});
[void](${script:Main-Window}.ShowDialog() | Out-Null);