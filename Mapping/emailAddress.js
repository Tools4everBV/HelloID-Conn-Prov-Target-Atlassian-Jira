function getEmail() {
    let mail = '';

    if (typeof Person.Accounts.MicrosoftActiveDirectory.userPrincipalName !== 'undefined' && Person.Accounts.MicrosoftActiveDirectory.userPrincipalName) {
        mail = Person.Accounts.MicrosoftActiveDirectory.userPrincipalName;
    }

    return mail;
}

getEmail();