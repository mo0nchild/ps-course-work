using namespace System;
using namespace System.Collections.Generic;
using namespace System.Windows.Controls;
using namespace System.Windows;
using namespace Microsoft;

class UserDataModel 
{
    [System.String] $local:Username;
    [System.String] $local:Password;
    [System.String] $local:Fullname;
    [System.String] $local:Description;

    [System.Boolean] $local:MayChangePassword;
    [System.Boolean] $local:PasswordNeverExpires;
    [System.Boolean] $local:Disabled;

    static [List[UserDataModel]] GetFromJson([System.String] $txt_path)
    {
        [List[UserDataModel]] $local:user_list = [List[UserDataModel]]::new(0);
        [System.String] $local:file_data = Get-Content -Path $txt_path;

        $local:file_data.Split(";") | ForEach-Object -Process {
            [System.String[]] $local:item_property = $PSItem.Split("|");
            $local:user_list.Add([UserDataModel]@{
                Username = $local:item_property[0];
                Password = $local:item_property[1];
                Fullname = $local:item_property[2];
                Description = $local:item_property[3];

                MayChangePassword = [Convert]::ToBoolean($local:item_property[4]);
                PasswordNeverExpires = [Convert]::ToBoolean($local:item_property[5]);
                Disabled = [Convert]::ToBoolean($local:item_property[6]);
            });
        }
        
        $local:user_list.RemoveAt($user_list.Count - 1);
        return $local:user_list;
    }
}

[void] (Add-Type -AssemblyName PresentationFramework);
function local:LoadXamlFormFile([string] ${local:File-Path})
{
    [Xml.XmlDocument] ${local:Xaml-File} = (Get-Content -Path ${local:File-Path});
    [Xml.XmlNodeReader] ${local:Xaml-Reader} = (New-Object System.Xml.XmlNodeReader ${Xaml-File});
    return ([Windows.Markup.XamlReader]::Load(${Xaml-Reader}));
}

try { ${script:Main-Window} = local:LoadXamlFormFile("$PSScriptRoot\view.xaml"); }
catch { Write-Host("Can't load Windows.Markup.XamlReader; ($PSItem.Exteption.Message)"); Exit; }

[List[UserDataModel]] ${script:Users-List} =  [List[UserDataModel]]::new(0);
[ListView] ${script:User-ListView} = ${script:Main-Window}.FindName("FileItemsListView");

[TextBox] $script:username_field = ${script:Main-Window}.FindName("UserNameTextBox");
[TextBox] $script:fullname_field = ${script:Main-Window}.FindName("FullNameTextBox");
[TextBox] $script:password_field = ${script:Main-Window}.FindName("PasswordTextBox");
[TextBox] $script:description_field = ${script:Main-Window}.FindName("DescriptionTextBox");

${script:Main-Window}.FindName("SelectFileButton").Add_Click({
    $local:filepath_dialog = [Win32.OpenFileDialog]@{
        FileName = "Text Windows User List";
        Filter = "Txt File (.txt)|*.txt";
        DefaultExt = ".txt";
    };
    try {
        if(($local:filepath_dialog).ShowDialog() -ne $global:true) { return [void]; }
        ${script:User-ListView}.Items.Clear();
        (${script:Users-List} = [UserDataModel]::GetFromJson($local:filepath_dialog.FileName)) | ForEach-Object -Process {
            ${script:User-ListView}.Items.Add($PSItem);
        };
    }
    catch { [MessageBox]::Show("Cannot read file; ($PSItem)","Error"); }
});

${script:User-ListView}.Add_MouseUp({
    if(${script:User-ListView}.SelectedIndex -eq -1) { return [void]; }

    $script:username_field.Text = (${script:Users-List}[${script:User-ListView}.SelectedIndex]).Username;
    $script:fullname_field.Text = (${script:Users-List}[${script:User-ListView}.SelectedIndex]).FullName;
    $script:password_field.Text = (${script:Users-List}[${script:User-ListView}.SelectedIndex]).Password;
    $script:description_field.Text = (${script:Users-List}[${script:User-ListView}.SelectedIndex]).Description;

    ${script:Main-Window}.FindName("MayChangePassword").IsChecked = (
        ${script:Users-List}[${script:User-ListView}.SelectedIndex]).MayChangePassword;
    ${script:Main-Window}.FindName("PasswordNeverExpires").IsChecked = (
        ${script:Users-List}[${script:User-ListView}.SelectedIndex]).PasswordNeverExpires;
    ${script:Main-Window}.FindName("UserDisabled").IsChecked = (
        ${script:Users-List}[${script:User-ListView}.SelectedIndex]).Disabled;
});

${script:Main-Window}.FindName("CreateUserButton").Add_Click({
    [UserDataModel] $local:selected_usermodel = (${script:Users-List}[${script:User-ListView}.SelectedIndex]);
    [Security.SecureString] $local:password_secure = [Security.SecureString]::new();
    
    for ([int]$i = 0; $i -lt $local:selected_usermodel.Password.Length; $i++) 
    { 
        $local:password_secure.AppendChar(($selected_usermodel.Password)[$i]); 
    }
    try
    {
        $local:cmdler_error = $global:null;
        if([String]::IsNullOrWhiteSpace($local:selected_usermodel.Password) -ne $true) 
        {
            (New-LocalUser -Name $local:selected_usermodel.Username -Password $local:password_secure `
                -Disabled:($selected_usermodel.Disabled) -ErrorVariable cmdler_error -ErrorAction SilentlyContinue);
        }
        else 
        { 
            (New-LocalUser -Name $local:selected_usermodel.Username  -NoPassword `
                -Disabled:($selected_usermodel.Disabled) -ErrorVariable cmdler_error -ErrorAction SilentlyContinue);
        }
        if($local:cmdler_error -ne $global:null) { throw [System.Exception]::new("Cmdlet Error"); }

        (Set-LocalUser -Name $local:selected_usermodel.Username -FullName $local:selected_usermodel.Fullname`
            -Description $local:selected_usermodel.Description -PasswordNeverExpires:($selected_usermodel.PasswordNeverExpires)`
            -UserMayChangePassword $selected_usermodel.MayChangePassword`
            -ErrorVariable cmdler_error -ErrorAction SilentlyContinue); 

        if($local:cmdler_error -ne $global:null) { throw [System.Exception]::new("Cmdlet Error"); }
        [MessageBox]::Show("User $($local:selected_usermodel.Username) was created","Success");
    }
    catch { [MessageBox]::Show("Cannot create user; ($PSItem)","Error"); }
});

${script:Main-Window}.ShowDialog() | Out-Null;