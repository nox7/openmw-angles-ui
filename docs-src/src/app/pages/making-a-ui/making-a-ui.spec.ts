import { ComponentFixture, TestBed } from '@angular/core/testing';

import { MakingAUi } from './making-a-ui';

describe('MakingAUi', () => {
  let component: MakingAUi;
  let fixture: ComponentFixture<MakingAUi>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MakingAUi]
    })
    .compileComponents();

    fixture = TestBed.createComponent(MakingAUi);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
