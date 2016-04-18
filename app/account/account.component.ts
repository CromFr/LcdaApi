import {Component, Input, OnInit} from "angular2/core";
import {HTTP_PROVIDERS}    from "angular2/http";
import {Router, RouteParams} from "angular2/router";

import {AccountService}   from "./account.service";
import {LoadingComponent, LoadingStatus}   from "../loading.component";


@Component({
    // templateUrl: "app/account/account.template.html",
    template: require("./account.template.html")(),
    directives:  [LoadingComponent],
    providers:   [HTTP_PROVIDERS, AccountService]
})
export class AccountComponent implements OnInit {
    constructor(private _accountService: AccountService, private _router: Router, private _routeParams: RouteParams) {}

    private loadingStatus: LoadingStatus = new LoadingStatus();

    ngOnInit() {
        this._accountService.exists(this._routeParams.get("account"))
            .subscribe(
                c => {
                    console.log(c);
                    if (c === true) {
                        this.loadingStatus.setSuccess();
                    }
                    else {
                        this.loadingStatus.setError("Ce compte n'existe pas");
                    }
                },
                error => console.error(error)
            );
    }




    private changePasswordForm = {
        oldPassword: "",
        newPassword: "",
        newPasswordCheck: "",
    };
    private changePasswordMsg: string;
    private changePasswordErrorMsg: string;
    public changePassword() {
        this.changePasswordMsg = "";
        this.changePasswordErrorMsg = "";

        this._accountService.changePassword(
                this._routeParams.get("account"),
                this.changePasswordForm.oldPassword,
                this.changePasswordForm.newPassword)
            .subscribe(
                c => {
                    this.changePasswordMsg = "Mot de passe modifié";
                    this.changePasswordForm = {
                        oldPassword: "",
                        newPassword: "",
                        newPasswordCheck: "",
                    };
                },
                error => {
                    if (error.status === 409) {
                        this.changePasswordErrorMsg = "Ancien mot de passe incorrect";
                    }
                    else {
                        this.changePasswordErrorMsg = "Erreur inconnue (" + error.status + ")";
                        console.error(error);
                    }
                }
            );
    }

}