import { ComponentFixture, TestBed } from '@angular/core/testing';

import { MakingAButton } from './making-a-button';

describe('MakingAButton', () => {
  let component: MakingAButton;
  let fixture: ComponentFixture<MakingAButton>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MakingAButton]
    })
    .compileComponents();

    fixture = TestBed.createComponent(MakingAButton);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
