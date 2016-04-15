import {Component, Input} from "angular2/core";


export class LoadingStatus {

    isOk(): boolean {
        return this.loaded && this.error == null;
    }
    isLoaded(): boolean {
        return this.loaded;
    }

    setSuccess() {
        this.loaded = true;
    }
    setError(err: string) {
        this.error = err;
        this.loaded = true;
    }


    private loaded: boolean = false;
    private error: string = null;
}

@Component({
    selector: "loading",
    template: `
        <div class="center">
            <div *ngIf="!status.isLoaded()" class="center preloader-wrapper big active">
                <div class="spinner-layer spinner-blue-only">
                    <div class="circle-clipper left">
                    <div class="circle"></div>
                    </div><div class="gap-patch">
                    <div class="circle"></div>
                    </div><div class="circle-clipper right">
                    <div class="circle"></div>
                    </div>
                </div>
            </div>
            <div *ngIf="status.isLoaded() && !status.isOk()" class="z-depth-1">
                <div class="red z-depth-1 white-text small-padding">
                    <i class="medium material-icons">error</i>
                    <h4>{{status.error.split('\n')[0]}}</h4>
                </div>
                <div class="small-padding left-align">
                    <pre>{{status.error}}</pre>
                </div>
            </div>
        </div>
    `
})
export class LoadingComponent {
    @Input() public status: LoadingStatus;
}