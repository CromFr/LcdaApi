import {Component, OnInit, AfterViewInit} from "angular2/core";
import {RouteConfig, ROUTER_DIRECTIVES, ROUTER_PROVIDERS} from "angular2/router";
import {HTTP_PROVIDERS}    from "angular2/http";

import {CredentialsService, Session} from "./credentials.service";
import {CharListComponent} from "./chars/list.component";
import {CharDetailsComponent} from "./chars/details.component";

declare var $: any;

@Component({
    selector:    "app",
    directives:  [ROUTER_DIRECTIVES],
    providers: [
        ROUTER_PROVIDERS,
        HTTP_PROVIDERS, CredentialsService
    ],
    templateUrl: "app/app.component.html",
})
@RouteConfig([
  {path: "/:account/characters",       name: "CharList",    component: CharListComponent}, // useAsDefault: true
  {path: "/:account/characters/:char", name: "CharDetails", component: CharDetailsComponent},
  {path: "/:account/characters/deleted/:char", name: "DeletedCharDetails", component: CharDetailsComponent, data: {deleted: true}},
])
export class AppComponent implements OnInit, AfterViewInit {
    constructor(private _credService: CredentialsService) {}

    ngOnInit() {
        this._credService.getSession()
            .subscribe(
                session => {
                    this.session = session;
                },
                error => {
                    console.error("getAccount() error:", <any>error);
                });
    }

    ngAfterViewInit() {
        if (!this.materializeInit) {
            this.materializeInit = true;
            $("#modal-login-button").leanModal();
            $("#sidebar-button").sideNav();
        }
    }

    public session: Session = {
        authenticated: false,
        admin: false,
        account: "INVALID"
    };

    logout() {
        this._credService.logout()
            .subscribe(
                res  => {
                    this.session = {
                        authenticated: false,
                        admin: false,
                        account: "INVALID"
                    };
                },
                error => console.error("logout() error: ", <any>error));
    }


    public loginForm = {
        login: "",
        password: ""
    };
    submitLoginForm() {
        let login = this.loginForm.login;
        let password = this.loginForm.password;
        this._credService.login(login, password)
            .subscribe(
                session  => {
                    this.session = session;
                    $("#modal-login").closeModal();
                },
                error => console.error("submitLoginForm() error: ", <any>error));
    }


    private materializeInit: boolean = false;
}