import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ContentImage } from './content-image';

describe('ContentImage', () => {
  let component: ContentImage;
  let fixture: ComponentFixture<ContentImage>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ContentImage]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ContentImage);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
