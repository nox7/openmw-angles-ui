import { ComponentFixture, TestBed } from '@angular/core/testing';

import { WhyUseAnglesui } from './why-use-anglesui';

describe('WhyUseAnglesui', () => {
  let component: WhyUseAnglesui;
  let fixture: ComponentFixture<WhyUseAnglesui>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [WhyUseAnglesui]
    })
    .compileComponents();

    fixture = TestBed.createComponent(WhyUseAnglesui);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
