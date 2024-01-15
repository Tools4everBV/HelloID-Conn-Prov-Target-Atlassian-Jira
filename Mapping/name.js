function getName() {
    let upn = '';

    if (typeof Person.Accounts.MicrosoftActiveDirectory.userPrincipalName !== 'undefined' && Person.Accounts.MicrosoftActiveDirectory.userPrincipalName) {
        upn = Person.Accounts.MicrosoftActiveDirectory.userPrincipalName;
    }

    return upn;
}

getName();