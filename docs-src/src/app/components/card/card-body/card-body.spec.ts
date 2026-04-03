import { ComponentFixture, TestBed } from '@angular/core/testing';

import { CardBody } from './card-body';

describe('CardBody', () => {
  let component: CardBody;
  let fixture: ComponentFixture<CardBody>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CardBody]
    })
    .compileComponents();

    fixture = TestBed.createComponent(CardBody);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
