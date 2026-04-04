import { Component } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { ContentImage } from "../../components/content-image/content-image";

@Component({
  selector: 'app-installing',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, ContentImage],
  templateUrl: './installing.html',
  styleUrl: './installing.scss',
})
export class Installing {

}
