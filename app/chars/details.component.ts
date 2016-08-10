import {Component, Input, OnInit} from "angular2/core";
import {Router, RouteParams, RouteData} from "angular2/router";
import {MaterializeDirective} from "angular2-materialize";

import {CharsService}   from "./chars.service";
import {CredentialsService} from "../credentials.service";
import {LoadingComponent, LoadingStatus}   from "../loading.component";
import {OrderBy}   from "../orderBy";

import {ToastService} from "../toast.service";

@Component({
    template:    require("./details.template")(),
    directives:  [LoadingComponent, MaterializeDirective],
    providers:   [CharsService, CredentialsService, ToastService],
    pipes: [OrderBy]
})
export class CharDetailsComponent implements OnInit {
    constructor(private _charsService: CharsService, private _credService: CredentialsService, private _toastService: ToastService,
                private _router: Router, private _data: RouteData, private _routeParams: RouteParams) {
        let deleted: boolean = _data.get("deleted");
        if (deleted != null && deleted === true)
            this.isDeletedChar = true;
    }


    ngOnInit() {
        this._charsService.getChar(this._routeParams.get("account"), this._routeParams.get("char"), this.isDeletedChar)
            .subscribe(
                data => {
                    this.character = data;
                    if(this.meta != null)
                        this.loadingStatus.setSuccess();
                },
                error => {
                    this.loadingStatus.setError(error.text());
                }
            );
        this._charsService.getMetadata(this._routeParams.get("account"), this._routeParams.get("char"), this.isDeletedChar)
            .subscribe(
                data => {
                    this.meta = data;
                    if(this.character != null)
                        this.loadingStatus.setSuccess();
                },
                error => {
                    this.loadingStatus.setError(error.text());
                }
            );

        //TODO: use session object from AppComponent
        this.session = this._credService.getSession()
            .subscribe(
                session => {
                    this.session = session;
                },
                error => {
                    console.error("getAccount() error:", <any>error);
                });
    }

    public loadingStatus: LoadingStatus = new LoadingStatus();

    private isDeletedChar: boolean = false;
    public character: any;
    public meta: any;


    private deleteErrorMsg: string;
    public deleteChar() {
        if (this.isDeletedChar === true) throw "Cannot delete a deactivated char";

        this._charsService.deleteChar(this._routeParams.get("account"), this._routeParams.get("char"))
            .subscribe(
                c => {
                    this.deleteErrorMsg = "";
                    let newName = c.newBicFile;
                    this._router.root.navigate(["DeletedCharDetails", {
                        account: this._routeParams.get("account"),
                        char: newName
                    }]);
                },
                error => {
                    this._toastService.longError(error._body);
                    console.error(error);
                }
            );
    }

    private activateErrorMsg: string;
    public activateChar() {
        if (this.isDeletedChar === false) throw "Cannot activate an active char";

        this._charsService.activateChar(this._routeParams.get("account"), this._routeParams.get("char"))
            .subscribe(
                c => {
                    this.activateErrorMsg = "";
                    let newName = c.newBicFile;
                    this._router.root.navigate(["CharDetails", {
                        account: this._routeParams.get("account"),
                        char: newName
                    }]);
                },
                error => {
                    if (error.status === 409) // conflict
                        this.activateErrorMsg = "Un personnage actif du même nom existe déja";
                    else {
                        this._toastService.longError(error._body);
                        console.error(error);
                    }
                }
            );
    }

    public setPublic(state: boolean) {
        this.meta.public = state;
        this._charsService
            .setMetadata(this._routeParams.get("account"), this._routeParams.get("char"), this.isDeletedChar, this.meta)
            .subscribe(
                c => {

                },
                error => {
                    this._toastService.longError(error._body);
                    console.error(error);
                }
            );
    }



    private downloadLink(): string {
        return "/" + this._routeParams.get("account")
            + "/characters/"
            + (this.isDeletedChar ? "deleted/" : "")
            + this._routeParams.get("char")
            + "/download";
    }

    private abilityModifier(value: number): string {
        let mod = Math.floor(value / 2) - 5;
        return (mod >= 0 ? "+" : "") + String(mod);
    }

    private session = null;
    private controlsDisabled(): boolean {

        if(this.session.authenticated
          && (this.session.admin || this._routeParams.get("account")==this.session.account)){
            return false;
        }
        return true;
    }

}