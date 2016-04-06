import {Component, OnInit, AfterViewInit} from "angular2/core";
import {Router, RouteConfig, ROUTER_DIRECTIVES, ROUTER_PROVIDERS} from "angular2/router";
import {HTTP_PROVIDERS}    from "angular2/http";

import {CredentialsService, Session} from "./credentials.service";
import {CharListComponent} from "./chars/list.component";
import {CharDetailsComponent} from "./chars/details.component";
import {HomeComponent} from "./home.component";

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
  {path: "/",                          name: "Home",        component: HomeComponent, useAsDefault: true},
  {path: "/:account/characters",       name: "CharList",    component: CharListComponent},
  {path: "/:account/characters/:char", name: "CharDetails", component: CharDetailsComponent},
  {path: "/:account/characters/deleted/:char", name: "DeletedCharDetails", component: CharDetailsComponent, data: {deleted: true}},
])
export class AppComponent implements OnInit, AfterViewInit {
    constructor(private _credService: CredentialsService, private _router: Router) {}

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

                    this._router.root.navigate(["Home"]);
                },
                error => console.error("logout() error: ", <any>error));
    }


    private loginForm = {
        login: "",
        password: ""
    };
    private loginErrorMsg: string;
    submitLoginForm() {
        let login = this.loginForm.login;
        let password = this.loginForm.password;
        this._credService.login(login, password)
            .subscribe(
                session  => {
                    this.session = session;
                    $("#modal-login").closeModal();
                    this.loginErrorMsg = "";

                    //Refresh
                    // window.location.replace(window.location.href);
                    this._router.root.navigate(["Home"]);
                },
                error => {
                    console.error("submitLoginForm() error: ", <any>error);
                    if (error.status === 401)
                        this.loginErrorMsg = "Compte inconnu / Mauvais mot de passe";
                    else
                        this.loginErrorMsg = "Erreur inconnue";

                });
    }


    private materializeInit: boolean = false;
}