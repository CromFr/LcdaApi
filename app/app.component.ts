import {Component, OnInit, AfterViewChecked} from "angular2/core";
import {Router, RouteConfig, ROUTER_DIRECTIVES, ROUTER_PROVIDERS} from "angular2/router";
import {HTTP_PROVIDERS}    from "angular2/http";
import {CredentialsService, Session} from "./credentials.service";
import {CharListComponent} from "./chars/list.component";
import {CharDetailsComponent} from "./chars/details.component";
import {HomeComponent} from "./home.component";
import {NewAccountComponent} from "./newaccount.component";
import {AccountComponent} from "./account/account.component";

// declare var $: any;
function materializeInit(selector: string, callback) {
    // let elmt = $(selector);
    // if (elmt.attr("materialize-init") === undefined) {
    //     elmt.attr("materialize-init", "");
    //     callback(elmt);
    // }
}
@Component({
    selector:    "app",
    directives:  [ROUTER_DIRECTIVES],
    providers: [
        ROUTER_PROVIDERS,
        HTTP_PROVIDERS, CredentialsService
    ],
    // templateUrl: "app/app.template.html",
    template: require("./app.template")()
})
@RouteConfig([
  {path: "/",                          name: "Home",        component: HomeComponent, useAsDefault: true},
  {path: "/newaccount",                name: "NewAccount",  component: NewAccountComponent},
  {path: "/:account/account",          name: "Account",     component: AccountComponent},
  {path: "/:account/characters",       name: "CharList",    component: CharListComponent},
  {path: "/:account/characters/:char", name: "CharDetails", component: CharDetailsComponent},
  {path: "/:account/characters/deleted/:char", name: "DeletedCharDetails", component: CharDetailsComponent, data: {deleted: true}},
])
export class AppComponent implements OnInit, AfterViewChecked {
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
    public session: Session = {
        authenticated: false,
        admin: false,
        account: "INVALID"
    };
    ngAfterViewChecked() {
        materializeInit("#modal-login-button", elmt => elmt.leanModal());
        materializeInit("#sidebar-button", elmt => elmt.sideNav());
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
                    this._router.commit(this._router.currentInstruction, true);
                },
                error => {
                    console.error("submitLoginForm() error: ", <any>error);
                    if (error.status === 401)
                        this.loginErrorMsg = "Compte inconnu / Mauvais mot de passe";
                    else
                        this.loginErrorMsg = "Erreur inconnue";
                });
    }
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
}